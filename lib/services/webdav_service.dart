import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../models/remote_file.dart';

/// WebDAV 服务 — 使用原始 Socket 实现 PROPFIND 和 GET
///
/// 核心问题：Android 上 dart:io HttpClient 底层走 Java HttpURLConnection，
/// 该类只支持标准 HTTP 方法（GET/POST/PUT/DELETE/HEAD 等），
/// 遇到 PROPFIND 等 WebDAV 专有方法直接返回 405 Method Not Allowed。
///
/// 解决方案：绕过 HttpClient，使用原始 [Socket] / [SecureSocket] 直接发送
/// HTTP/1.1 请求字节，完全控制 HTTP 方法、请求头和请求体。
class WebDavService {
  final String baseUrl;
  final String username;
  final String password;

  WebDavService({
    required this.baseUrl,
    required this.username,
    required this.password,
  });

  String get _authHeader {
    final credentials = base64Encode(utf8.encode('$username:$password'));
    return 'Basic $credentials';
  }

  /// 构建请求 URI
  ///
  /// 确保路径以 / 结尾（WebDAV 服务器通常要求目录路径带尾斜杠）
  Uri _buildUri(String path) {
    final base = Uri.parse(baseUrl);
    final basePath = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    final dirPath = path.startsWith('/') ? path : '/$path';
    var fullPath = basePath + dirPath;

    final portStr = base.hasPort && base.port != 80 && base.port != 443
        ? ':${base.port}'
        : '';
    final urlStr = '${base.scheme}://${base.host}$portStr$fullPath';
    return Uri.parse(urlStr);
  }

  // ──────────────────────────── 原始 HTTP 请求引擎 ────────────────────────────

  /// 通过原始 Socket 发送 HTTP 请求并接收完整响应
  ///
  /// 完全绕过 dart:io HttpClient，直接在 TCP 层面收发 HTTP/1.1 字节。
  /// 支持自动跟随重定向（301/302/307/308）。
  Future<_RawHttpResponse> _rawRequest({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    String? body,
    int maxRedirects = 5,
    int redirectCount = 0,
  }) async {
    final isSecure = uri.scheme == 'https';
    final host = uri.host;
    final port = uri.port;
    final path = uri.path.isEmpty ? '/' : uri.path;

    // 建立 TCP 连接
    Socket socket;
    if (isSecure) {
      socket = await SecureSocket.connect(
        host,
        port,
        onBadCertificate: (_) => true, // 允许自签名证书
        timeout: const Duration(seconds: 15),
      );
    } else {
      socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 15),
      );
    }

    try {
      // ── 构造 HTTP/1.1 请求文本 ──
      final bodyBytes = body != null ? utf8.encode(body) : null;
      final sb = StringBuffer();
      sb.writeln('$method $path HTTP/1.1');
      sb.writeln('Host: $host$portStr(host, port, isSecure, uri)');
      for (final entry in headers.entries) {
        sb.writeln('${entry.key}: ${entry.value}');
      }
      if (bodyBytes != null) {
        sb.writeln('Content-Length: ${bodyBytes.length}');
      }
      sb.writeln('Connection: close');
      sb.writeln(); // 空行分隔 header 和 body

      // 发送请求头
      socket.add(utf8.encode(sb.toString()));
      // 发送请求体
      if (bodyBytes != null) {
        socket.add(bodyBytes);
      }
      await socket.flush();

      // ── 读取完整响应 ──
      final responseBytes = BytesBuilder();
      await for (final chunk in socket.timeout(
        const Duration(seconds: 30),
        onTimeout: (sink) {
          sink.addError(TimeoutException('读取响应超时'));
          sink.close();
        },
      )) {
        responseBytes.add(chunk);
      }

      final responseStr = utf8.decode(responseBytes.toBytes());
      final parsed = _parseHttpResponse(responseStr);

      // ── 处理重定向 ──
      if (parsed.statusCode >= 300 &&
          parsed.statusCode < 400 &&
          parsed.statusCode != 304) {
        if (redirectCount >= maxRedirects) {
          throw Exception('服务器重定向次数过多（超过 $maxRedirects 次）');
        }

        final location = parsed.headers['location'];
        if (location == null || location.isEmpty) {
          throw Exception(
              '服务器返回重定向 (HTTP ${parsed.statusCode}) 但未提供目标地址');
        }

        Uri redirectUri;
        if (location.startsWith('http://') || location.startsWith('https://')) {
          redirectUri = Uri.parse(location);
        } else if (location.startsWith('/')) {
          redirectUri = uri.replace(path: location);
        } else {
          final basePath =
              uri.path.substring(0, uri.path.lastIndexOf('/') + 1);
          redirectUri = uri.replace(path: basePath + location);
        }

        debugPrint('[WebDAV] 重定向 ${parsed.statusCode}: $uri -> $redirectUri');
        return _rawRequest(
          method: method,
          uri: redirectUri,
          headers: headers,
          body: body,
          maxRedirects: maxRedirects,
          redirectCount: redirectCount + 1,
        );
      }

      return parsed;
    } finally {
      try {
        await socket.close();
      } catch (_) {}
    }
  }

  /// 格式化 Host 头的端口号
  String portStr(String host, int port, bool isSecure, Uri uri) {
    if (uri.hasPort && port != 80 && port != 443) {
      return ':$port';
    }
    return '';
  }

  /// 解析原始 HTTP 响应文本为结构化对象
  _RawHttpResponse _parseHttpResponse(String response) {
    // 查找 header 和 body 的分隔线
    final headerEnd = response.indexOf('\r\n\r\n');
    if (headerEnd == -1) {
      throw Exception('无效的 HTTP 响应格式');
    }

    final headerSection = response.substring(0, headerEnd);
    var bodySection = response.substring(headerEnd + 4);

    // 解析状态行：HTTP/1.1 207 Multi-Status
    final lines = headerSection.split('\r\n');
    if (lines.isEmpty) {
      throw Exception('HTTP 响应为空');
    }

    final statusParts = lines.first.split(' ');
    if (statusParts.length < 2) {
      throw Exception('无法解析 HTTP 状态行: ${lines.first}');
    }
    final statusCode = int.tryParse(statusParts[1]) ?? 0;

    // 解析响应头
    final headers = <String, String>{};
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i];
      final colonIndex = line.indexOf(':');
      if (colonIndex != -1) {
        final key = line.substring(0, colonIndex).trim().toLowerCase();
        final value = line.substring(colonIndex + 1).trim();
        headers[key] = value;
      }
    }

    // 处理分块传输编码 (chunked transfer encoding)
    if (headers['transfer-encoding']?.toLowerCase().contains('chunked') ==
        true) {
      bodySection = _decodeChunked(bodySection);
    }

    return _RawHttpResponse(statusCode, headers, bodySection);
  }

  /// 解码分块传输编码
  String _decodeChunked(String chunked) {
    final sb = StringBuffer();
    var pos = 0;
    while (pos < chunked.length) {
      // 找到块大小的行结束位置
      final lineEnd = chunked.indexOf('\r\n', pos);
      if (lineEnd == -1) break;

      final sizeStr = chunked.substring(pos, lineEnd).trim();
      // 块大小可能包含分号后面的扩展参数，只取前面十六进制数字
      final semiIndex = sizeStr.indexOf(';');
      final hexStr =
          semiIndex != -1 ? sizeStr.substring(0, semiIndex) : sizeStr;
      final size = int.tryParse(hexStr, radix: 16);
      if (size == null || size == 0) break;

      final dataStart = lineEnd + 2;
      if (dataStart + size > chunked.length) break;

      sb.write(chunked.substring(dataStart, dataStart + size));
      pos = dataStart + size + 2; // 跳过块数据 + \r\n
    }
    return sb.toString();
  }

  // ──────────────────────────── WebDAV 操作接口 ────────────────────────────

  /// PROPFIND — 列出目录内容
  Future<List<RemoteFile>> propfind(String path) async {
    // PROPFIND 用于目录列表，确保路径以 / 结尾
    var propfindPath = path;
    if (!propfindPath.endsWith('/')) {
      propfindPath += '/';
    }
    final uri = _buildUri(propfindPath);

    const propfindXml = '<?xml version="1.0" encoding="utf-8"?>'
        '<D:propfind xmlns:D="DAV:">'
        '<D:prop>'
        '<D:displayname/>'
        '<D:resourcetype/>'
        '<D:getcontentlength/>'
        '<D:getlastmodified/>'
        '</D:prop>'
        '</D:propfind>';

    try {
      final resp = await _rawRequest(
        method: 'PROPFIND',
        uri: uri,
        headers: {
          'Authorization': _authHeader,
          'Depth': '1',
          'Content-Type': 'application/xml; charset=utf-8',
          'User-Agent': 'Amber-MD/6.0.5',
        },
        body: propfindXml,
      );

      // 认证失败
      if (resp.statusCode == 401 || resp.statusCode == 403) {
        throw Exception('认证失败: 用户名或密码错误');
      }

      // 405 = Method Not Allowed
      if (resp.statusCode == 405) {
        throw Exception(
          '服务器不支持 PROPFIND 方法 (HTTP 405)。\n'
          '请确认服务器地址正确，并检查是否需要包含完整路径（如 /dav/）',
        );
      }

      // 404 = 路径不存在
      if (resp.statusCode == 404) {
        throw Exception('路径不存在，请检查服务器地址或目录路径是否正确');
      }

      // 其他错误
      if (resp.statusCode >= 400) {
        throw Exception(
          '服务器返回错误: HTTP ${resp.statusCode}\n'
          '${resp.body.length > 200 ? resp.body.substring(0, 200) : resp.body}',
        );
      }

      // WebDAV PROPFIND 应返回 207 Multi-Status
      if (resp.statusCode != 207) {
        throw Exception('服务器响应异常: HTTP ${resp.statusCode}（期望 207）');
      }

      final body = resp.body;
      if (!body.contains('multistatus') && !body.contains('response')) {
        throw Exception('服务器返回了无效的 WebDAV 响应');
      }

      return _parsePropfindResponse(body, path);
    } on SocketException catch (e) {
      if (e.message.contains('Failed host lookup') ||
          e.message.contains('Name or service not known')) {
        throw Exception('无法解析服务器地址，请检查域名是否正确或网络连接');
      } else if (e.message.contains('Connection refused')) {
        throw Exception('服务器拒绝连接，请检查端口是否正确');
      }
      throw Exception('网络连接失败: ${e.message}');
    } on TimeoutException {
      throw Exception('连接超时，请检查服务器地址和网络');
    } on HandshakeException catch (e) {
      throw Exception('SSL/TLS 握手失败: ${e.message}');
    }
  }

  /// GET — 下载文件
  ///
  /// 使用原始 Socket 流式下载，支持大文件
  Future<void> downloadFile(String remotePath, String localPath) async {
    final uri = _buildUri(remotePath);
    // 下载文件时不需要尾斜杠
    final fileUri = uri.toString().replaceAll(RegExp(r'/$'), '');
    final parsedUri = Uri.parse(fileUri);

    final isSecure = parsedUri.scheme == 'https';
    final host = parsedUri.host;
    final port = parsedUri.port;
    final path = parsedUri.path;

    Socket socket;
    if (isSecure) {
      socket = await SecureSocket.connect(
        host,
        port,
        onBadCertificate: (_) => true,
        timeout: const Duration(seconds: 15),
      );
    } else {
      socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 15),
      );
    }

    try {
      // 发送 GET 请求
      final request = 'GET $path HTTP/1.1\r\n'
          'Host: $host${parsedUri.hasPort && port != 80 && port != 443 ? ':$port' : ''}\r\n'
          'Authorization: $_authHeader\r\n'
          'Accept: */*\r\n'
          'User-Agent: Amber-MD/6.0.5\r\n'
          'Connection: close\r\n'
          '\r\n';

      socket.add(utf8.encode(request));
      await socket.flush();

      // 读取响应头
      final headerBuilder = BytesBuilder();
      var headerEndIndex = -1;
      int? statusCode;
      int? contentLength;
      bool isChunked = false;

      await for (final chunk in socket.timeout(
        const Duration(seconds: 30),
        onTimeout: (sink) {
          sink.addError(TimeoutException('下载超时'));
          sink.close();
        },
      )) {
        headerBuilder.add(chunk);
        final headerBytes = headerBuilder.toBytes();

        // 查找 header 结束标记 \r\n\r\n
        for (var i = 0; i < headerBytes.length - 3; i++) {
          if (headerBytes[i] == 0x0D &&
              headerBytes[i + 1] == 0x0A &&
              headerBytes[i + 2] == 0x0D &&
              headerBytes[i + 3] == 0x0A) {
            headerEndIndex = i + 4;
            break;
          }
        }

        if (headerEndIndex != -1) {
          // 解析状态码和 Content-Length
          final headerStr = utf8.decode(headerBytes.sublist(0, headerEndIndex));
          final headerLines = headerStr.split('\r\n');
          if (headerLines.isNotEmpty) {
            final statusParts = headerLines.first.split(' ');
            if (statusParts.length >= 2) {
              statusCode = int.tryParse(statusParts[1]);
            }
          }
          for (final line in headerLines) {
            final lower = line.toLowerCase();
            if (lower.startsWith('content-length:')) {
              contentLength = int.tryParse(line.substring(15).trim());
            } else if (lower.contains('transfer-encoding') &&
                lower.contains('chunked')) {
              isChunked = true;
            }
          }

          // 认证失败
          if (statusCode == 401 || statusCode == 403) {
            throw Exception('认证失败: 用户名或密码错误');
          }
          if (statusCode != null && statusCode >= 400) {
            throw Exception('下载失败: 服务器返回 $statusCode');
          }

          // 写入文件（跳过 header 部分）
          final bodyData = headerBytes.sublist(headerEndIndex);
          final file = File(localPath);
          final sink = file.openWrite();
          sink.add(bodyData);

          // 如果不是 chunked 且知道 content length，继续读取剩余数据
          if (!isChunked) {
            await for (final remaining in socket) {
              sink.add(remaining as Uint8List);
            }
          }

          await sink.flush();
          await sink.close();
          return;
        }
      }

      // 如果读完整个响应还没找到 header 结束标记
      throw Exception('下载失败: 无效的服务器响应');
    } on SocketException catch (e) {
      throw Exception('网络连接失败: ${e.message}');
    } on TimeoutException {
      throw Exception('下载超时');
    } on HandshakeException catch (e) {
      throw Exception('SSL/TLS 握手失败: ${e.message}');
    } finally {
      try {
        await socket.close();
      } catch (_) {}
    }
  }

  // ──────────────────────────── XML 响应解析 ────────────────────────────

  /// 解析 PROPFIND XML 响应为文件列表
  List<RemoteFile> _parsePropfindResponse(String xml, String requestPath) {
    final files = <RemoteFile>[];

    // 匹配每个 <D:response>...</D:response> 块
    final responseRegex = RegExp(
      r'<[a-zA-Z0-9:]+response[^>]*>(.*?)</[a-zA-Z0-9:]+response>',
      dotAll: true,
    );
    final matches = responseRegex.allMatches(xml);

    for (final match in matches) {
      final resp = match.group(1)!;

      // 判断是否为目录
      var isDir = RegExp(r'<[a-zA-Z0-9:]+collection\s*/\s*>', dotAll: true)
              .hasMatch(resp) ||
          RegExp(
            r'<[a-zA-Z0-9:]+collection[^>]*>\s*</[a-zA-Z0-9:]+collection>',
            dotAll: true,
          ).hasMatch(resp);

      // 提取 href
      final hrefMatch = RegExp(
        r'<[a-zA-Z0-9:]+href[^>]*>([^<]*)</[a-zA-Z0-9:]+href>',
      ).firstMatch(resp);
      if (hrefMatch == null) continue;

      var rawHref = Uri.decodeFull(hrefMatch.group(1)!.trim());
      if (!isDir) {
        isDir = rawHref.endsWith('/');
      }

      // 提取 displayname
      final nameMatch = RegExp(
        r'<[a-zA-Z0-9:]+displayname[^>]*>([^<]*)</[a-zA-Z0-9:]+displayname>',
      ).firstMatch(resp);

      String name;
      if (nameMatch != null && nameMatch.group(1)!.trim().isNotEmpty) {
        name = nameMatch.group(1)!.trim();
      } else {
        var href = rawHref;
        if (href.endsWith('/')) href = href.substring(0, href.length - 1);
        final segments =
            href.split('/').where((s) => s.isNotEmpty).toList();
        name = segments.isNotEmpty ? segments.last : '';
      }

      if (name.isEmpty || name == '.') continue;

      // 跳过自身目录项
      final baseUri = Uri.parse(baseUrl);
      final basePath = baseUri.path.endsWith('/')
          ? baseUri.path.substring(0, baseUri.path.length - 1)
          : baseUri.path;
      final normalizedReqPath = (basePath + requestPath).endsWith('/')
          ? (basePath + requestPath)
              .substring(0, (basePath + requestPath).length - 1)
          : (basePath + requestPath);
      final normalizedHref = rawHref.endsWith('/')
          ? rawHref.substring(0, rawHref.length - 1)
          : rawHref;

      if (normalizedHref == normalizedReqPath ||
          normalizedHref == baseUri.path ||
          normalizedHref.isEmpty) {
        continue;
      }

      files.add(RemoteFile(name, isDir));
    }

    // 排序：目录优先，然后按字母排序
    files.sort((a, b) {
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;
      return a.name.compareTo(b.name);
    });

    return files;
  }
}

/// 原始 HTTP 响应结构
class _RawHttpResponse {
  final int statusCode;
  final Map<String, String> headers;
  final String body;

  const _RawHttpResponse(this.statusCode, this.headers, this.body);
}

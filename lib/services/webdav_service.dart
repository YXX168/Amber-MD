import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../models/remote_file.dart';

/// WebDAV 服务 — 使用 http 包 + IOClient 实现 PROPFIND 和 GET
///
/// 修复：dart:io HttpClient 的 openUrl 对 PROPFIND 方法兼容性差（部分服务器返回 405）
/// 改用 http 包的 Request 对象，可精确控制 method / headers / body
class WebDavService {
  final String baseUrl;
  final String username;
  final String password;

  WebDavService({
    required this.baseUrl,
    required this.username,
    required this.password,
  });

  /// 创建带 Basic Auth 的 IOClient
  http.Client get _client {
    final credentials = base64Encode(utf8.encode('$username:$password'));
    return IOClient(HttpClient()
      ..addCredentials(
        // 对所有请求自动附加凭据
        Uri.parse(baseUrl),
        'Any Realm',
        HttpClientBasicCredentials(username, password),
      )
      ..badCertificateCallback =
          (_, __, ___) => true // 允许自签名证书
    );
  }

  String get _authHeader {
    final credentials = base64Encode(utf8.encode('$username:$password'));
    return 'Basic $credentials';
  }

  Uri _buildUri(String path) {
    final base = Uri.parse(baseUrl);
    final basePath = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    final dirPath = path.startsWith('/') ? path : '/$path';
    final fullPath = basePath + dirPath;

    final portStr = base.hasPort && base.port != 80 && base.port != 443
        ? ':${base.port}'
        : '';
    final urlStr =
        '${base.scheme}://${base.host}$portStr$fullPath';
    return Uri.parse(urlStr);
  }

  /// PROPFIND 请求 — 列出目录内容
  Future<List<RemoteFile>> propfind(String path) async {
    final uri = _buildUri(path);

    const propfindXml = '<?xml version="1.0" encoding="utf-8"?>'
        '<D:propfind xmlns:D="DAV:">'
        '<D:prop>'
        '<D:displayname/>'
        '<D:resourcetype/>'
        '<D:getcontentlength/>'
        '<D:getlastmodified/>'
        '</D:prop>'
        '</D:propfind>';

    final bodyBytes = utf8.encode(propfindXml);

    try {
      final request = http.Request('PROPFIND', uri);
      request.headers.addAll({
        'Authorization': _authHeader,
        'Depth': '1',
        'Content-Type': 'application/xml; charset=utf-8',
        'Content-Length': bodyBytes.length.toString(),
        'User-Agent': 'Amber-MD/6.0',
      });
      request.bodyBytes = bodyBytes;

      final client = _client;
      try {
        final streamedResp = await client.send(request).timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                throw TimeoutException('PROPFIND 请求超时');
              },
            );

        final resp = await http.Response.fromStream(streamedResp).timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                throw TimeoutException('读取响应超时');
              },
            );

        // 认证失败
        if (resp.statusCode == 401 || resp.statusCode == 403) {
          throw Exception('认证失败: 用户名或密码错误');
        }

        // 405 = Method Not Allowed，通常是 URL 路径问题
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
      } finally {
        client.close();
      }
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
    } on http.ClientException catch (e) {
      throw Exception('连接失败: ${e.message}');
    }
  }

  /// 解析 PROPFIND XML 响应
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

  /// GET 请求 — 下载文件
  Future<void> downloadFile(String remotePath, String localPath) async {
    final uri = _buildUri(remotePath);

    try {
      final request = http.Request('GET', uri);
      request.headers.addAll({
        'Authorization': _authHeader,
        'Accept': '*/*',
        'User-Agent': 'Amber-MD/6.0',
      });

      final client = _client;
      try {
        final streamedResp = await client.send(request).timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                throw TimeoutException('GET 请求超时');
              },
            );

        if (streamedResp.statusCode == 401 ||
            streamedResp.statusCode == 403) {
          throw Exception('认证失败: 用户名或密码错误');
        }
        if (streamedResp.statusCode >= 400) {
          throw Exception('下载失败: 服务器返回 ${streamedResp.statusCode}');
        }

        // 流式写入文件，支持大文件
        final file = File(localPath);
        final sink = file.openWrite();
        try {
          await for (final chunk in streamedResp.stream) {
            sink.add(chunk as Uint8List);
          }
          await sink.flush();
          await sink.close();
        } catch (e) {
          await sink.close();
          rethrow;
        }
      } finally {
        client.close();
      }
    } on SocketException catch (e) {
      throw Exception('网络连接失败: ${e.message}');
    } on TimeoutException {
      throw Exception('下载超时');
    }
  }
}

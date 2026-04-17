import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/remote_file.dart';

/// WebDAV 服务 — 使用 dart:io HttpClient 实现 PROPFIND 和 GET
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

  Uri _buildUri(String path) {
    final base = Uri.parse(baseUrl);
    final basePath = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    final dirPath = path.startsWith('/') ? path : '/$path';
    final fullPath = basePath + dirPath;

    final encodedSegments =
        fullPath.split('/').map((s) => s.isEmpty ? s : Uri.encodeComponent(s)).join('/');
    final portStr = base.hasPort ? ':${base.port}' : '';
    final urlStr = '${base.scheme}://${base.host}$portStr$encodedSegments';
    return Uri.parse(urlStr);
  }

  /// PROPFIND 请求 — 列出目录内容
  Future<List<RemoteFile>> propfind(String path) async {
    final uri = _buildUri(path);

    const propfindXml = '<?xml version="1.0" encoding="utf-8"?>'
        '<D:propfind xmlns:D="DAV:">'
        '<D:prop><D:displayname/><D:resourcetype/>'
        '</D:prop></D:propfind>';

    final client = HttpClient();
    try {
      String currentUrl = uri.toString();
      int redirectCount = 0;
      const maxRedirects = 5;

      while (true) {
        final req = await client
            .openUrl('PROPFIND', Uri.parse(currentUrl))
            .timeout(const Duration(seconds: 15));
        req.headers.set('Authorization', _authHeader);
        req.headers.set('Depth', '1');
        req.headers.set('Content-Type', 'application/xml; charset=utf-8');
        req.headers.set('Content-Length', '${utf8.encode(propfindXml).length}');
        req.write(propfindXml);

        final resp = await req.close().timeout(const Duration(seconds: 15));

        if (resp.statusCode == 401 || resp.statusCode == 403) {
          await resp.drain<void>();
          throw Exception('认证失败: 用户名或密码错误');
        }

        if (resp.statusCode >= 300 && resp.statusCode < 400) {
          final location = resp.headers.value('location');
          await resp.drain<void>();
          if (location == null || location.isEmpty) {
            throw Exception('服务器返回重定向但未提供目标地址');
          }
          redirectCount++;
          if (redirectCount > maxRedirects) {
            throw Exception('服务器重定向次数过多');
          }
          final base = Uri.parse(baseUrl);
          if (location.startsWith('/')) {
            final portStr = base.hasPort ? ':${base.port}' : '';
            currentUrl = '${base.scheme}://${base.host}$portStr$location';
          } else {
            currentUrl = location;
          }
          continue;
        }

        if (resp.statusCode >= 400) {
          final body = await resp.transform(utf8.decoder).join();
          final truncated =
              body.length > 200 ? body.substring(0, 200) : body;
          throw Exception('服务器返回错误: ${resp.statusCode} $truncated');
        }

        final body = await resp.transform(utf8.decoder).join();

        if (resp.statusCode != 207) {
          throw Exception('服务器响应异常: HTTP ${resp.statusCode}');
        }

        if (!body.contains('multistatus') && !body.contains('response')) {
          throw Exception('服务器返回了无效的WebDAV响应');
        }

        return _parsePropfindResponse(body, path);
      }
    } on SocketException catch (e) {
      if (e.message.contains('Failed host lookup')) {
        throw Exception('无法解析服务器地址，请检查域名是否正确或网络连接');
      } else if (e.message.contains('Connection refused')) {
        throw Exception('服务器拒绝连接，请检查端口是否正确');
      }
      throw Exception('网络连接失败: ${e.message}');
    } on TimeoutException {
      throw Exception('连接超时，请检查服务器地址和网络');
    } finally {
      client.close();
    }
  }

  /// 解析 PROPFIND XML 响应
  List<RemoteFile> _parsePropfindResponse(String xml, String requestPath) {
    final files = <RemoteFile>[];

    final responseRegex = RegExp(
      r'<[a-zA-Z0-9:]+response[^>]*>(.*?)</[a-zA-Z0-9:]+response>',
      dotAll: true,
    );
    final matches = responseRegex.allMatches(xml);

    for (final match in matches) {
      final resp = match.group(1)!;

      var isDir =
          RegExp(r'<[a-zA-Z0-9:]+collection\s*/\s*>', dotAll: true)
                  .hasMatch(resp) ||
              RegExp(
                r'<[a-zA-Z0-9:]+collection[^>]*>\s*</[a-zA-Z0-9:]+collection>',
                dotAll: true,
              ).hasMatch(resp);

      final hrefMatch = RegExp(
        r'<[a-zA-Z0-9:]+href[^>]*>([^<]*)</[a-zA-Z0-9:]+href>',
      ).firstMatch(resp);
      if (hrefMatch == null) continue;

      var rawHref = Uri.decodeFull(hrefMatch.group(1)!.trim());
      if (!isDir) {
        isDir = rawHref.endsWith('/');
      }

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

      // 跳过自身目录
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

    final client = HttpClient();
    try {
      final req =
          await client.getUrl(uri).timeout(const Duration(seconds: 15));
      req.headers.set('Authorization', _authHeader);
      req.headers.set('Accept', '*/*');

      final resp = await req.close().timeout(const Duration(seconds: 30));

      if (resp.statusCode == 401 || resp.statusCode == 403) {
        await resp.drain<void>();
        throw Exception('认证失败: 用户名或密码错误');
      }
      if (resp.statusCode >= 400) {
        await resp.drain<void>();
        throw Exception('下载失败: 服务器返回 ${resp.statusCode}');
      }

      final file = File(localPath);
      final sink = file.openWrite();
      await resp.pipe(sink);
    } finally {
      client.close();
    }
  }
}

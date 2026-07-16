import 'package:amber_md/services/webdav_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('WebDAV URL normalization prefers secure public connections', () {
    expect(normalizeWebDavUrl('dav.example.com/dav/'),
        'https://dav.example.com/dav');
    expect(normalizeWebDavUrl('https://dav.example.com/dav///'),
        'https://dav.example.com/dav');
  });

  test('WebDAV URL normalization keeps local NAS usable over HTTP', () {
    expect(normalizeWebDavUrl('192.168.1.20:5005/dav'),
        'http://192.168.1.20:5005/dav');
    expect(normalizeWebDavUrl('nas.local/dav'), 'http://nas.local/dav');
  });
}

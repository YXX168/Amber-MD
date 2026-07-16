import 'package:amber_md/services/preferences_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.init();
  });

  test('reading progress is clamped, persisted and removable', () async {
    await PreferencesService.setReadingProgress('/docs/readme.md', 1.4);

    expect(PreferencesService.getReadingProgress('/docs/readme.md'), 1);

    await PreferencesService.clearReadingProgress('/docs/readme.md');

    expect(PreferencesService.getReadingProgress('/docs/readme.md'), 0);
  });

  test('self-signed certificate preference defaults off', () async {
    expect(PreferencesService.webdavAllowSelfSigned, isFalse);

    await PreferencesService.setWebdavAllowSelfSigned(true);

    expect(PreferencesService.webdavAllowSelfSigned, isTrue);
  });
}

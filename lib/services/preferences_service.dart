import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences 封装服务
class PreferencesService {
  static SharedPreferences? _prefs;

  /// 初始化 SharedPreferences 实例
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// 获取 SharedPreferences 实例
  static SharedPreferences get prefs {
    if (_prefs == null) {
      throw StateError('PreferencesService 尚未初始化，请先调用 init()');
    }
    return _prefs!;
  }

  // ─── 主题相关 ─────────────────────────────────────────────────

  static const String keyThemeMode = 'theme_mode';
  static const String keyFontSize = 'font_size';
  static const String keyLineHeight = 'line_height';
  static const String keyLetterSpacing = 'letter_spacing';

  static String get themeMode => prefs.getString(keyThemeMode) ?? 'midnight';
  static int get fontSizeIndex => prefs.getInt(keyFontSize) ?? 1;
  static double get lineHeight => prefs.getDouble(keyLineHeight) ?? 1.75;
  static double get letterSpacing => prefs.getDouble(keyLetterSpacing) ?? 0.0;

  static Future<void> setThemeMode(String id) =>
      prefs.setString(keyThemeMode, id);

  static Future<void> setFontSizeIndex(int index) =>
      prefs.setInt(keyFontSize, index);

  static Future<void> setLineHeight(double h) =>
      prefs.setDouble(keyLineHeight, h);

  static Future<void> setLetterSpacing(double sp) =>
      prefs.setDouble(keyLetterSpacing, sp);

  // ─── 最近文件 ─────────────────────────────────────────────────

  static const String keyRecentFiles = 'recent_files';

  static List<String> get recentFiles =>
      prefs.getStringList(keyRecentFiles) ?? [];

  static Future<void> setRecentFiles(List<String> files) =>
      prefs.setStringList(keyRecentFiles, files);

  // ─── WebDAV 凭据 ──────────────────────────────────────────────

  static const String keyWebdavUrl = 'webdav_url';
  static const String keyWebdavUsername = 'webdav_username';
  static const String keyWebdavPassword = 'webdav_password';
  static const String keyWebdavRemember = 'webdav_remember';

  static String get webdavUrl => prefs.getString(keyWebdavUrl) ?? '';
  static String get webdavUsername => prefs.getString(keyWebdavUsername) ?? '';
  static String get webdavPassword => prefs.getString(keyWebdavPassword) ?? '';
  static bool get webdavRemember => prefs.getBool(keyWebdavRemember) ?? true;

  static Future<void> setWebdavCredentials({
    required String url,
    required String username,
    required String password,
    required bool remember,
  }) async {
    if (remember) {
      await prefs.setString(keyWebdavUrl, url);
      await prefs.setString(keyWebdavUsername, username);
      await prefs.setString(keyWebdavPassword, password);
    }
    await prefs.setBool(keyWebdavRemember, remember);
  }

  static Future<void> clearWebdavCredentials() async {
    await prefs.remove(keyWebdavUrl);
    await prefs.remove(keyWebdavUsername);
    await prefs.remove(keyWebdavPassword);
    await prefs.remove(keyWebdavRemember);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'models/app_theme.dart';
import 'pages/home_page.dart';
import 'pages/reader_page.dart';
import 'pages/network_storage_page.dart';
import 'pages/settings_page.dart';
import 'providers/theme_provider.dart';
import 'services/preferences_service.dart';
import 'package:receive_intent/receive_intent.dart' as ri;

/// 应用入口点 — Amber MD v6.0
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await PreferencesService.init();

  // 处理冷启动 Intent
  try {
    final receivedIntent = await ri.ReceiveIntent.getInitialIntent();
    if (receivedIntent != null) {
      final filePath = await _extractFilePathFromIntent(receivedIntent);
      if (filePath != null) {
        initialFilePath = filePath;
        debugPrint('[Intent] 初始接收到文件: $filePath');
      }
    }
  } catch (e) {
    debugPrint('Failed to receive initial intent: $e');
  }

  // 监听运行时 Intent（热启动）
  ri.ReceiveIntent.receivedIntentStream.listen(
    (intent) async {
      try {
        debugPrint('[Intent] 收到运行时 Intent 变化');
        final filePath = await _extractFilePathFromIntent(intent);
        if (filePath != null) {
          debugPrint('[Intent] 运行时接收到文件: $filePath');
          if (globalIntentFileCallback != null) {
            globalIntentFileCallback!(filePath);
          } else {
            initialFilePath = filePath;
          }
        }
      } catch (e) {
        debugPrint('[Intent] 处理运行时 Intent 失败: $e');
      }
    },
    onError: (e) {
      debugPrint('[Intent] 监听错误: $e');
    },
  );

  runApp(const GlassMdApp());
}

/// 解析 content:// URI 为本地临时文件路径
Future<String?> _resolveContentUri(String uri) async {
  try {
    if (!uri.startsWith('content://')) return uri;
    final platform = MethodChannel('com.amber.md/content_resolver');
    final String? localPath =
        await platform.invokeMethod<String>('resolveContentUri', {'uri': uri});
    return localPath;
  } catch (e) {
    debugPrint('Failed to resolve content URI: $e');
  }
  return null;
}

/// 从 ReceiveIntent 中提取文件路径
Future<String?> _extractFilePathFromIntent(ri.Intent? intent) async {
  if (intent == null || intent.isNull) return null;
  final extra = intent.extra;
  if (extra != null && extra.containsKey('android.intent.extra.STREAM')) {
    final rawPath = extra['android.intent.extra.STREAM'] as String?;
    if (rawPath != null) {
      return await _resolveContentUri(rawPath);
    }
  }
  if (intent.data != null) {
    final data = intent.data!;
    if (data.startsWith('content://')) {
      return await _resolveContentUri(data);
    } else if (data.isNotEmpty) {
      return data;
    }
  }
  if (extra != null) {
    final textExtra = extra['android.intent.extra.TEXT'] as String?;
    if (textExtra != null && textExtra.isNotEmpty) {
      if (textExtra.startsWith('content://')) {
        return await _resolveContentUri(textExtra);
      } else if (textExtra.startsWith('file://') || textExtra.startsWith('/')) {
        return textExtra;
      }
    }
  }
  return null;
}

/// Amber MD 主应用 Widget
class GlassMdApp extends StatelessWidget {
  const GlassMdApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ThemeProvider(
      child: Builder(
        builder: (context) {
          final tp = ThemeProvider.of(context);
          return ValueListenableBuilder<int>(
            valueListenable: globalThemeVersion,
            builder: (context, _, __) {
              final theme = tp.currentTheme;
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInOut,
                child: MaterialApp(
                  key: ValueKey('app_${globalThemeVersion.value}'),
                  title: 'Amber MD',
                  debugShowCheckedModeBanner: false,
                  localizationsDelegates: const [
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  supportedLocales: const [
                    Locale('zh', 'CN'),
                    Locale('en', 'US'),
                  ],
                  locale: const Locale('zh', 'CN'),
                  theme: ThemeData(
                    brightness: theme.brightness,
                    colorScheme: theme.brightness == Brightness.dark
                        ? ColorScheme.dark(
                            primary: theme.primaryColor,
                            secondary: theme.accentColor,
                            surface: theme.surfaceColor,
                            onSurface: theme.textColor,
                          )
                        : ColorScheme.light(
                            primary: theme.primaryColor,
                            secondary: theme.accentColor,
                            surface: theme.surfaceColor,
                            onSurface: theme.textColor,
                          ),
                    scaffoldBackgroundColor: theme.bgGradientColors[0],
                    useMaterial3: true,
                    textSelectionTheme: TextSelectionThemeData(
                      selectionColor:
                          theme.primaryColor.withValues(alpha: 0.3),
                      cursorColor: theme.primaryColor,
                      selectionHandleColor: theme.primaryColor,
                    ),
                    textTheme: theme.brightness == Brightness.dark
                        ? GoogleFonts.interTextTheme(
                            ThemeData.dark().textTheme)
                        : GoogleFonts.interTextTheme(
                            ThemeData.light().textTheme),
                  ),
                  home: const HomePage(),
                  onGenerateRoute: (settings) {
                    Route<dynamic> _buildPageTransition(Widget page) {
                      return PageRouteBuilder<dynamic>(
                        settings: settings,
                        transitionDuration: const Duration(milliseconds: 300),
                        reverseTransitionDuration:
                            const Duration(milliseconds: 250),
                        pageBuilder: (context, anim, secondary) {
                          return FadeTransition(
                            opacity: CurvedAnimation(
                                parent: anim,
                                curve: Curves.easeOutCubic),
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.04),
                                end: Offset.zero,
                              ).animate(anim),
                              child: page,
                            ),
                          );
                        },
                      );
                    }

                    if (settings.name == '/reader') {
                      final args = settings.arguments;
                      if (args is! Map<String, dynamic>) {
                        return _buildPageTransition(const Scaffold(
                            body: Center(
                                child: Text('无效的参数'))));
                      }
                      return _buildPageTransition(
                        ReaderPage(
                          filePath: args['path'] as String? ?? '',
                          fileType: args['fileType'] as String? ?? 'md',
                        ),
                      );
                    }
                    if (settings.name == '/network_storage') {
                      final args = settings.arguments;
                      if (args is! Map<String, dynamic>) {
                        return _buildPageTransition(const Scaffold(
                            body: Center(
                                child: Text('无效的参数'))));
                      }
                      return _buildPageTransition(
                        NetworkStoragePage(
                          storageType:
                              args['type'] as String? ?? 'webdav',
                        ),
                      );
                    }
                    if (settings.name == '/settings') {
                      return _buildPageTransition(const SettingsPage());
                    }
                    return null;
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

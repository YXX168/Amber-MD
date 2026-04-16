import 'dart:async';
import 'dart:ui';
import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:receive_intent/receive_intent.dart' as ri;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

// 全局回调：处理运行时收到的 Intent（应用已在运行时从其他应用跳转过来）
typedef IntentFileCallback = void Function(String filePath);
IntentFileCallback? _globalIntentFileCallback;

// ═══════════════════════════════════════════════════════════════════════
// THEME SYSTEM
// ═══════════════════════════════════════════════════════════════════════

enum AppThemeMode { midnight, aurora, forest, ocean, sakura }

class AppTheme {
  final String name;
  final String id;
  final List<Color> bgGradientColors;
  final Alignment bgGradientBegin;
  final Alignment bgGradientEnd;
  final Color primaryColor;
  final Color accentColor;
  final Color surfaceColor;
  final Color cardBg;
  final Color textColor;
  final Color textSecondary;
  final Brightness brightness;
  final Color fabColor;
  final Color fabBorderColor;
  final Color shimmerColor;

  const AppTheme({
    required this.name,
    required this.id,
    required this.bgGradientColors,
    this.bgGradientBegin = Alignment.topLeft,
    this.bgGradientEnd = Alignment.bottomRight,
    required this.primaryColor,
    required this.accentColor,
    required this.surfaceColor,
    required this.cardBg,
    required this.textColor,
    required this.textSecondary,
    required this.brightness,
    required this.fabColor,
    required this.fabBorderColor,
    required this.shimmerColor,
  });
}

const _appThemes = {
  AppThemeMode.midnight: AppTheme(
    name: '午夜',
    id: 'midnight',
    bgGradientColors: [Color(0xFF14142e), Color(0xFF1a1a3c), Color(0xFF16142c)],
    primaryColor: Color(0xFF9B8AFF),
    accentColor: Color(0xFF7EC8E3),
    surfaceColor: Color(0xFF1C1C36),
    cardBg: Color(0x10FFFFFF),
    textColor: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFE8E8F8),
    brightness: Brightness.dark,
    fabColor: Color(0x309B8AFF),
    fabBorderColor: Color(0x509B8AFF),
    shimmerColor: Color(0x149B8AFF),
  ),
  AppThemeMode.aurora: AppTheme(
    name: '极光',
    id: 'aurora',
    bgGradientColors: [
      Color(0xFF0a1020),
      Color(0xFF0e1e40),
      Color(0xFF0c1830),
      Color(0xFF0e1228),
    ],
    bgGradientBegin: Alignment.topLeft,
    bgGradientEnd: Alignment.bottomRight,
    primaryColor: Color(0xFF6EE7B7),
    accentColor: Color(0xFF818CF8),
    surfaceColor: Color(0xFF0F1830),
    cardBg: Color(0x146EE7B7),
    textColor: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFE8F0F8),
    brightness: Brightness.dark,
    fabColor: Color(0x286EE7B7),
    fabBorderColor: Color(0x406EE7B7),
    shimmerColor: Color(0x146EE7B7),
  ),
  AppThemeMode.forest: AppTheme(
    name: '森林',
    id: 'forest',
    bgGradientColors: [Color(0xFFFCFEFA), Color(0xFFF4FAF0), Color(0xFFF8FCF4)],
    bgGradientBegin: Alignment.topCenter,
    bgGradientEnd: Alignment.bottomCenter,
    primaryColor: Color(0xFF16A34A),
    accentColor: Color(0xFF22C55E),
    surfaceColor: Color(0xFFFFFFFF),
    cardBg: Color(0x0616A34A),
    textColor: Color(0xFF063316),
    textSecondary: Color(0xFF107030),
    brightness: Brightness.light,
    fabColor: Color(0x2016A34A),
    fabBorderColor: Color(0x3816A34A),
    shimmerColor: Color(0x0616A34A),
  ),
  AppThemeMode.ocean: AppTheme(
    name: '海洋',
    id: 'ocean',
    bgGradientColors: [Color(0xFFFBFDFF), Color(0xFFEEF6FF), Color(0xFFF3F9FF)],
    bgGradientBegin: Alignment.topCenter,
    bgGradientEnd: Alignment.bottomCenter,
    primaryColor: Color(0xFF2563EB),
    accentColor: Color(0xFF3B82F6),
    surfaceColor: Color(0xFFFFFFFF),
    cardBg: Color(0x062563EB),
    textColor: Color(0xFF051d44),
    textSecondary: Color(0xFF1840AF),
    brightness: Brightness.light,
    fabColor: Color(0x202563EB),
    fabBorderColor: Color(0x382563EB),
    shimmerColor: Color(0x062563EB),
  ),
  AppThemeMode.sakura: AppTheme(
    name: '樱落',
    id: 'sakura',
    bgGradientColors: [Color(0xFFFFFCFD), Color(0xFFFDF4F7), Color(0xFFFEF8FA)],
    bgGradientBegin: Alignment.topCenter,
    bgGradientEnd: Alignment.bottomCenter,
    primaryColor: Color(0xFFDB2777),
    accentColor: Color(0xFFEC4899),
    surfaceColor: Color(0xFFFFFFFF),
    cardBg: Color(0x06DB2777),
    textColor: Color(0xFF2D0A15),
    textSecondary: Color(0xFF802060),
    brightness: Brightness.light,
    fabColor: Color(0x20DB2777),
    fabBorderColor: Color(0x38DB2777),
    shimmerColor: Color(0x06DB2777),
  ),
};

enum FontSizeOption { small, medium, large }

const _fontSizeMap = {
  FontSizeOption.small: 13.0,
  FontSizeOption.medium: 15.0,
  FontSizeOption.large: 18.0,
};
const _fontSizeLabels = {
  FontSizeOption.small: '小',
  FontSizeOption.medium: '中',
  FontSizeOption.large: '大',
};

// ═══════════════════════════════════════════════════════════════════════
// GLOBAL THEME NOTIFIER (for real-time theme switching across all pages)
// ═══════════════════════════════════════════════════════════════════════

/// Global theme change counter — incremented on every theme/font/lineHeight change.
/// All pages listen to this via AnimatedBuilder to rebuild instantly.
final ValueNotifier<int> globalThemeVersion = ValueNotifier<int>(0);

// ═══════════════════════════════════════════════════════════════════════
// THEME PROVIDER (global state + SharedPreferences persistence)
// ═══════════════════════════════════════════════════════════════════════

class ThemeProvider extends StatefulWidget {
  final Widget child;
  const ThemeProvider({super.key, required this.child});

  static _ThemeProviderState of(BuildContext context) {
    final state = context.findAncestorStateOfType<_ThemeProviderState>();
    if (state == null) {
      throw FlutterError('ThemeProvider not found in widget tree. Make sure your widget is wrapped in ThemeProvider.');
    }
    return state;
  }

  @override
  State<ThemeProvider> createState() => _ThemeProviderState();
}

class _ThemeProviderState extends State<ThemeProvider> {
  AppThemeMode _mode = AppThemeMode.midnight;
  FontSizeOption _fontSize = FontSizeOption.medium;
  double _lineHeight = 1.75;
  double _letterSpacing = 0.0;

  AppTheme get currentTheme => _appThemes[_mode]!;
  AppThemeMode get mode => _mode;
  FontSizeOption get fontSizeOption => _fontSize;
  double get fontSize => _fontSizeMap[_fontSize]!;
  double get lineHeight => _lineHeight;
  double get letterSpacing => _letterSpacing;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final themeId = prefs.getString('theme_mode') ?? 'midnight';
    final fontIdx = prefs.getInt('font_size') ?? 1;
    final lh = prefs.getDouble('line_height') ?? 1.75;
    final ls = prefs.getDouble('letter_spacing') ?? 0.0;
    if (!mounted) return;
    setState(() {
      _mode = AppThemeMode.values.firstWhere(
        (m) => _appThemes[m]!.id == themeId,
        orElse: () => AppThemeMode.midnight,
      );
      _fontSize = FontSizeOption.values[fontIdx.clamp(0, FontSizeOption.values.length - 1)];
      _lineHeight = lh;
      _letterSpacing = ls;
    });
    // Notify all listeners after loading
    globalThemeVersion.value++;
  }

  Future<void> setTheme(AppThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', _appThemes[mode]!.id);
    // v5.4: Trigger smooth cross-fade theme transition
    globalThemeTransition.value = 0.0;
    Future.delayed(const Duration(milliseconds: 50), () {
      globalThemeTransition.value = 1.0;
    });
    setState(() => _mode = mode);
    // Force all pages to rebuild with new theme
    globalThemeVersion.value++;
  }

  Future<void> setFontSize(FontSizeOption opt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('font_size', opt.index);
    setState(() => _fontSize = opt);
    globalThemeVersion.value++;
  }

  Future<void> setLineHeight(double h) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('line_height', h);
    setState(() => _lineHeight = h);
    globalThemeVersion.value++;
  }

  Future<void> setLetterSpacing(double sp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('letter_spacing', sp);
    setState(() => _letterSpacing = sp);
    globalThemeVersion.value++;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ═══════════════════════════════════════════════════════════════════════
// GLOBAL THEME NOTIFIER (for real-time theme switching across all pages)
// ═══════════════════════════════════════════════════════════════════════

/// Global theme transition notifier — triggers cross-fade animation
final ValueNotifier<double> globalThemeTransition = ValueNotifier<double>(1.0);
// ═══════════════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════════════

String? _initialFilePath;

/// Resolve content:// URI to a local temp file path using Android ContentResolver
Future<String?> _resolveContentUri(String uri) async {
  try {
    if (!uri.startsWith('content://')) return uri;
    final platform = MethodChannel('com.amber.md/content_resolver');
    final String? localPath = await platform.invokeMethod<String>('resolveContentUri', {'uri': uri});
    return localPath;
  } catch (e) {
    debugPrint('Failed to resolve content URI: $e');
  }
  return null;
}

/// Extract file path from a ReceiveIntent entity
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
  // Check for extra text (some apps send file path as text)
  if (extra != null) {
    final textExtra = extra['android.intent.extra.TEXT'] as String?;
    if (textExtra != null && textExtra.isNotEmpty) {
      // Could be a file path or URI
      if (textExtra.startsWith('content://')) {
        return await _resolveContentUri(textExtra);
      } else if (textExtra.startsWith('file://') || textExtra.startsWith('/')) {
        return textExtra;
      }
    }
  }
  return null;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // 处理初始 Intent（应用冷启动时）
  try {
    final receivedIntent = await ri.ReceiveIntent.getInitialIntent();
    if (receivedIntent != null) {
      final filePath = await _extractFilePathFromIntent(receivedIntent);
      if (filePath != null) {
        _initialFilePath = filePath;
        debugPrint('[Intent] 初始接收到文件: $filePath');
      }
    }
  } catch (e) {
    debugPrint('Failed to receive initial intent: $e');
  }

  // 监听运行时 Intent 变化（应用已在后台运行时，从其他应用跳转过来）
  ri.ReceiveIntent.receivedIntentStream.listen(
    (intent) async {
      try {
        debugPrint('[Intent] 收到运行时 Intent 变化');
        final filePath = await _extractFilePathFromIntent(intent);
        if (filePath != null) {
          debugPrint('[Intent] 运行时接收到文件: $filePath');
          // 如果全局回调已注册（HomePage），调用它来打开文件
          if (_globalIntentFileCallback != null) {
            _globalIntentFileCallback!(filePath);
          } else {
            // 否则存为初始路径，等 HomePage 初始化后处理
            _initialFilePath = filePath;
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

class GlassMdApp extends StatelessWidget {
  const GlassMdApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ThemeProvider(
      child: Builder(
        builder: (context) {
          final tp = ThemeProvider.of(context);
          // Use ValueListenableBuilder to force MaterialApp rebuild on theme change
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
                  title: 'Amber',
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
                selectionColor: theme.primaryColor.withValues(alpha: 0.3),
                cursorColor: theme.primaryColor,
                selectionHandleColor: theme.primaryColor,
              ),
              textTheme: theme.brightness == Brightness.dark
                  ? GoogleFonts.interTextTheme(ThemeData.dark().textTheme)
                  : GoogleFonts.interTextTheme(ThemeData.light().textTheme),
            ),
            home: const HomePage(),
            onGenerateRoute: (settings) {
              Route<dynamic> _buildPageTransition(Widget page) {
                return PageRouteBuilder<dynamic>(
                  settings: settings,
                  transitionDuration: const Duration(milliseconds: 300),
                  reverseTransitionDuration: const Duration(milliseconds: 250),
                  pageBuilder: (context, anim, secondary) {
                    return FadeTransition(
                      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
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
                  return _buildPageTransition(const Scaffold(body: Center(child: Text('无效的参数'))));
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
                  return _buildPageTransition(const Scaffold(body: Center(child: Text('无效的参数'))));
                }
                return _buildPageTransition(
                  NetworkStoragePage(storageType: args['type'] as String? ?? 'webdav'),
                );
              }
              if (settings.name == '/settings') {
                return _buildPageTransition(const SettingsPage());
              }
              return null;
            },
          ),
        },
      ),
    ),
  );
  }
}

// ─── App Bar Card - 毛玻璃效果标题栏 ──────────────────────────────
// v5.4: 进一步降低不透明度，增强模糊穿透效果
class _AppBarCard extends StatelessWidget {
  final Widget child;
  const _AppBarCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final tp = ThemeProvider.of(context);
    final theme = tp.currentTheme;
    final isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF0D0D1A).withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.30),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.18)
                  : theme.primaryColor.withValues(alpha: 0.25),
              width: 0.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─── Glass FAB — 毛玻璃浮动按钮，与标题栏模糊度一致 ──────────────────
// v5.4: 新组件，用于返回顶部等浮动按钮，保持与标题栏一致
class _GlassFAB extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final double borderRadius;
  const _GlassFAB({super.key, required this.child, required this.onTap, this.borderRadius = 24});

  @override
  Widget build(BuildContext context) {
    final tp = ThemeProvider.of(context);
    final theme = tp.currentTheme;
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0D0D1A).withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.18)
                    : theme.primaryColor.withValues(alpha: 0.25),
                width: 0.5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────

String _getFileType(String path) {
  final ext = p.extension(path).toLowerCase().replaceAll('.', '');
  if (ext == 'md' || ext == 'markdown') return 'md';
  if (ext == 'txt' || ext == 'text') return 'txt';
  if (ext == 'html' || ext == 'htm') return 'html';
  if (ext == 'json') return 'json';
  return 'plain';
}

String _getFileTypeLabel(String path) {
  final ext = p.extension(path).toLowerCase().replaceAll('.', '');
  const labels = {
    'md': 'MD', 'markdown': 'MD', 'txt': 'TXT', 'text': 'TXT',
    'html': 'HTML', 'htm': 'HTML', 'json': 'JSON', 'xml': 'XML',
    'yaml': 'YAML', 'yml': 'YAML', 'csv': 'CSV', 'log': 'LOG',
    'cfg': 'CFG', 'ini': 'INI', 'conf': 'CONF',
  };
  return labels[ext] ?? ext.toUpperCase();
}

// ═══════════════════════════════════════════════════════════════════════
// Animated gradient background — OPTIMIZED for v3.0
// ═══════════════════════════════════════════════════════════════════════
class AnimatedGradientBg extends StatefulWidget {
  final Widget child;
  const AnimatedGradientBg({super.key, required this.child});

  @override
  State<AnimatedGradientBg> createState() => _AnimatedGradientBgState();
}

class _AnimatedGradientBgState extends State<AnimatedGradientBg>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12), // Slower animation = less GPU load
    )..repeat(reverse: true);
    globalThemeVersion.addListener(_onThemeChanged);
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    globalThemeVersion.removeListener(_onThemeChanged);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tp = ThemeProvider.of(context);
    final theme = tp.currentTheme;
    final colors = theme.bgGradientColors;
    final isAurora = theme.id == 'aurora';

    // Use RepaintBoundary to isolate painting
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: theme.bgGradientBegin,
                end: theme.bgGradientEnd,
                colors: isAurora
                    ? [
                        Color.lerp(colors[0], colors[1], 0.5 + 0.5 * sin(_ctrl.value * 2 * pi))!,
                        Color.lerp(colors[1], colors[2], 0.5 + 0.5 * cos(_ctrl.value * 2 * pi))!,
                        Color.lerp(colors[2], colors.length > 3 ? colors[3] : colors[0], 0.5 + 0.5 * sin(_ctrl.value * 2 * pi + 1.0))!,
                        Color.lerp(colors[0], colors[1], 0.3 + 0.3 * cos(_ctrl.value * 2 * pi + 2.0))!,
                      ]
                    : [
                        Color.lerp(colors[0], colors[1], _ctrl.value * 0.3)!,
                        colors.length > 2
                            ? Color.lerp(colors[1], colors[2], _ctrl.value * 0.2)!
                            : colors[1],
                        Color.lerp(colors[0], colors.length > 2 ? colors[2] : colors[1], 1 - _ctrl.value * 0.3)!,
                      ],
              ),
            ),
            child: widget.child,
          );
        },
      ),
    );
  }
}

// ─── Glass card widget — OPTIMIZED for v3.0 ──────────────────────────
class GlassCard extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final double blur;
  final Color? color;
  final Border? border;
  final VoidCallback? onTap;
  final Duration animationDelay;
  final bool animate;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.padding,
    this.blur = 20,
    this.color,
    this.border,
    this.onTap,
    this.animationDelay = Duration.zero,
    this.animate = false,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      Future.delayed(widget.animationDelay, () {
        if (mounted) setState(() => _visible = true);
      });
    } else {
      _visible = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tp = ThemeProvider.of(context);
    final theme = tp.currentTheme;
    final isDark = theme.brightness == Brightness.dark;

    // Remove ValueListenableBuilder wrapper for better performance
    // Theme changes will be handled by parent rebuilds
    return AnimatedOpacity(
      opacity: _visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      child: AnimatedScale(
        scale: _visible ? 1.0 : 0.95,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        child: GestureDetector(
          onTap: widget.onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: Container(
              padding: widget.padding ?? const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.color ??
                    (isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : theme.primaryColor.withValues(alpha: 0.06)),
                borderRadius: BorderRadius.circular(widget.borderRadius),
                border: widget.border ??
                    Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : theme.primaryColor.withValues(alpha: 0.12),
                      width: 1,
                    ),
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Shimmer / light sweep effect — OPTIMIZED for v3.0 ──────────────
class ShimmerSweep extends StatefulWidget {
  final Widget child;
  const ShimmerSweep({super.key, required this.child});

  @override
  State<ShimmerSweep> createState() => _ShimmerSweepState();
}

class _ShimmerSweepState extends State<ShimmerSweep>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4), // Slower = less GPU load
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tp = ThemeProvider.of(context);
    final theme = tp.currentTheme;

    // Use RepaintBoundary to isolate painting
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          return ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                begin: Alignment(-1.0 - _ctrl.value * 2, 0),
                end: Alignment(1.0 - _ctrl.value * 2, 0),
                colors: [
                  Colors.transparent,
                  theme.shimmerColor,
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ).createShader(bounds);
            },
            blendMode: BlendMode.srcATop,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

// ─── Home Page ──────────────────────────────────────────────────────
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<String> _recentFiles = [];

  @override
  void initState() {
    super.initState();
    _loadRecent();

    // 注册全局 Intent 回调（处理应用已在运行时从其他应用跳转过来的情况）
    _globalIntentFileCallback = (filePath) {
      debugPrint('[HomePage] 全局回调收到文件: $filePath');
      if (mounted) {
        _addToRecent(filePath);
        Navigator.pushNamed(context, '/reader', arguments: {
          'path': filePath,
          'fileType': _getFileType(filePath),
        });
      }
    };

    // 处理初始 intent 文件
    if (_initialFilePath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final fp = _initialFilePath!;
        _initialFilePath = null;
        _addToRecent(fp);
        Navigator.pushNamed(context, '/reader', arguments: {
          'path': fp,
          'fileType': _getFileType(fp),
        });
      });
    }
  }

  @override
  void dispose() {
    // 清除全局回调
    if (_globalIntentFileCallback != null) {
      _globalIntentFileCallback = null;
    }
    super.dispose();
  }

  Future<void> _loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _recentFiles = prefs.getStringList('recent_files') ?? [];
    });
  }

  Future<void> _addToRecent(String path) async {
    final prefs = await SharedPreferences.getInstance();
    _recentFiles.remove(path);
    _recentFiles.insert(0, path);
    if (_recentFiles.length > 20) _recentFiles = _recentFiles.sublist(0, 20);
    await prefs.setStringList('recent_files', _recentFiles);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'md', 'markdown', 'txt', 'html', 'htm',
          'json', 'xml', 'yaml', 'yml', 'csv',
          'log', 'cfg', 'ini', 'conf', 'text',
        ],
      );
      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        await _addToRecent(filePath);
        if (mounted) {
          Navigator.pushNamed(context, '/reader', arguments: {
            'path': filePath,
            'fileType': _getFileType(filePath),
          });
        }
      }
    } catch (e) {
      debugPrint('[HomePage] 文件选择失败: $e');
      if (mounted) {
        final tp = ThemeProvider.of(context);
        final theme = tp.currentTheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('无法选择文件: $e', style: GoogleFonts.inter(color: Colors.white)),
            backgroundColor: Colors.redAccent.withValues(alpha: 0.8),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _removeRecent(String path) async {
    // v5.4: Haptic feedback on delete
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    _recentFiles.remove(path);
    await prefs.setStringList('recent_files', _recentFiles);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // FIX: Wrap in ValueListenableBuilder for instant theme updates on home page
    return ValueListenableBuilder<int>(
      valueListenable: globalThemeVersion,
      builder: (context, _, __) {
        final tp = ThemeProvider.of(context);
        final theme = tp.currentTheme;
        final isDark = theme.brightness == Brightness.dark;

      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: isDark
            ? const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarIconBrightness: Brightness.light,
              )
            : const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.dark,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarIconBrightness: Brightness.dark,
              ),
        child: Scaffold(
          extendBody: true,
          extendBodyBehindAppBar: true,
          body: AnimatedGradientBg(
            child: SafeArea(
              top: true,
              bottom: false,
              child: Column(
                children: [
                  // Top bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [theme.primaryColor, theme.accentColor],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.auto_stories_rounded, color: Colors.white, size: 15),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Amber',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: theme.textColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          _GlassIconButton(
                            icon: Icons.folder_open_rounded,
                            onTap: _pickFile,
                            compact: true,
                          ),
                          const SizedBox(width: 2),
                          _GlassIconButton(
                            icon: Icons.cloud_outlined,
                            onTap: () => Navigator.pushNamed(context, '/network_storage',
                                arguments: {'type': 'webdav'}),
                            compact: true,
                          ),
                          const SizedBox(width: 2),
                          _GlassIconButton(
                            icon: Icons.settings_rounded,
                            onTap: () => Navigator.pushNamed(context, '/settings'),
                            compact: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Recent files
                  Expanded(
                    child: _recentFiles.isEmpty
                        ? _EmptyState(onPick: _pickFile)
                        : ListView.builder(
                            padding: EdgeInsets.fromLTRB(
                              20, 0, 20, MediaQuery.of(context).padding.bottom + 100,
                            ),
                            itemCount: _recentFiles.length + 1,
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    '最近文档',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: theme.textSecondary.withValues(alpha: 0.5),
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                );
                              }
                              final filePath = _recentFiles[index - 1];
                              return _AnimatedListItem(
                                index: index - 1,
                                child: _FileCard(
                                  filePath: filePath,
                                  onTap: () {
                                    _addToRecent(filePath);
                                    Navigator.pushNamed(context, '/reader', arguments: {
                                      'path': filePath,
                                      'fileType': _getFileType(filePath),
                                    });
                                  },
                                  onDismiss: () => _removeRecent(filePath),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: _buildFab(),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        ),
      );
      },
    );
  }

  Widget _buildFab() {
    return _FabButton(
      themeBuilder: () => ThemeProvider.of(context).currentTheme,
      onTap: _pickFile,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// FAB BUTTON - 带按下缩放反馈
// ═══════════════════════════════════════════════════════════════════════

class _FabButton extends StatefulWidget {
  final AppTheme Function() themeBuilder;
  final VoidCallback onTap;

  const _FabButton({required this.themeBuilder, required this.onTap});

  @override
  State<_FabButton> createState() => _FabButtonState();
}

class _FabButtonState extends State<_FabButton> with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.94,
      upperBound: 1.0,
    );
    _scaleAnim = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    );
    _scaleController.value = 1.0;
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _scaleController.animateTo(0.94, duration: const Duration(milliseconds: 100), curve: Curves.easeOutCubic);
  }

  void _onTapUp(TapUpDetails details) {
    _scaleController.animateTo(1.0, duration: const Duration(milliseconds: 200), curve: Curves.elasticOut);
  }

  void _onTapCancel() {
    _scaleController.animateTo(1.0, duration: const Duration(milliseconds: 150), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.themeBuilder();

    return ScaleTransition(
      scale: _scaleAnim,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: widget.onTap,
        child: GlassCard(
          borderRadius: 28,
          padding: EdgeInsets.zero,
          color: theme.fabColor,
          border: Border.all(color: theme.fabBorderColor, width: 1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, color: theme.textColor, size: 24),
                const SizedBox(width: 10),
                Text(
                  '打开文档',
                  style: GoogleFonts.inter(
                    color: theme.textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



class _GlassIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool compact;
  const _GlassIconButton({required this.icon, required this.onTap, this.compact = false});

  @override
  State<_GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<_GlassIconButton> with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.88,
      upperBound: 1.0,
    );
    _scaleAnim = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutCubic,
    );
    _scaleController.value = 1.0;
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _scaleController.animateTo(0.88, duration: const Duration(milliseconds: 80), curve: Curves.easeOutCubic);
  }

  void _onTapUp(TapUpDetails details) {
    _scaleController.animateTo(1.0, duration: const Duration(milliseconds: 200), curve: Curves.elasticOut);
    widget.onTap();
  }

  void _onTapCancel() {
    _scaleController.animateTo(1.0, duration: const Duration(milliseconds: 150), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final tp = ThemeProvider.of(context);
    final theme = tp.currentTheme;
    final isDark = theme.brightness == Brightness.dark;
    final btnSize = widget.compact ? 40.0 : 44.0;
    final iconSize = widget.compact ? 20.0 : 22.0;

    return ScaleTransition(
      scale: _scaleAnim,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : theme.primaryColor.withValues(alpha: 0.08),
          child: InkWell(
            onTapDown: _onTapDown,
            onTapUp: _onTapUp,
            onTapCancel: _onTapCancel,
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: btnSize,
              height: btnSize,
              child: Icon(widget.icon, color: theme.textSecondary, size: iconSize),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatefulWidget {
  final VoidCallback onPick;
  const _EmptyState({required this.onPick});

  @override
  State<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<_EmptyState> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tp = ThemeProvider.of(context);
    final theme = tp.currentTheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // v5.4: Enhanced logo animation with scale, rotation, and glow pulse
          AnimatedBuilder(
            animation: _ctrl,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + _ctrl.value * 0.15,
                child: Transform.rotate(
                  angle: _ctrl.value * 0.08,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.primaryColor.withValues(alpha: 0.3 + _ctrl.value * 0.15),
                          theme.accentColor.withValues(alpha: 0.1 + _ctrl.value * 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: theme.primaryColor.withValues(alpha: 0.15 + _ctrl.value * 0.25),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.primaryColor.withValues(alpha: 0.15 + _ctrl.value * 0.3),
                          blurRadius: 30 + _ctrl.value * 25,
                          spreadRadius: 3 + _ctrl.value * 8,
                        ),
                      ],
                    ),
                    child: Icon(Icons.description_rounded,
                        size: 44,
                        color: theme.textSecondary.withValues(alpha: 0.6 + _ctrl.value * 0.35)),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            '暂无文档',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: theme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '打开一个文件开始阅读',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: theme.textSecondary.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// ANIMATED LIST ITEM - 交错延迟进场动画
// ═══════════════════════════════════════════════════════════════════════

class _AnimatedListItem extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration baseDelay;
  final Duration staggerDelay;

  const _AnimatedListItem({
    required this.child,
    required this.index,
    this.baseDelay = const Duration(milliseconds: 100),
    this.staggerDelay = const Duration(milliseconds: 60),
  });

  @override
  State<_AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<_AnimatedListItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnim;
  late Animation<Offset> _slideAnim;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _opacityAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    // 交错延迟启动
    final delay = widget.baseDelay + (widget.staggerDelay * widget.index);
    _delayTimer = Timer(delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: widget.child,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// SETTINGS CARD - 带按下反馈的设置页卡片
// ═══════════════════════════════════════════════════════════════════════

class _SettingsCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Border? border;
  final bool animate;
  final Duration animationDelay;

  const _SettingsCard({
    required this.child,
    this.onTap,
    this.borderRadius = 14,
    this.padding = const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
    this.color,
    this.border,
    this.animate = false,
    this.animationDelay = Duration.zero,
  });

  @override
  State<_SettingsCard> createState() => _SettingsCardState();
}

class _SettingsCardState extends State<_SettingsCard> with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.96,
      upperBound: 1.0,
    );
    _scaleAnim = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    );
    _scaleController.value = 1.0;
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap != null) {
      _scaleController.animateTo(0.96, duration: const Duration(milliseconds: 100), curve: Curves.easeOutCubic);
    }
  }

  void _onTapUp(TapUpDetails details) {
    _scaleController.animateTo(1.0, duration: const Duration(milliseconds: 150), curve: Curves.easeOutCubic);
  }

  void _onTapCancel() {
    _scaleController.animateTo(1.0, duration: const Duration(milliseconds: 150), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnim,
      child: GestureDetector(
        onTapDown: widget.onTap != null ? _onTapDown : null,
        onTapUp: widget.onTap != null ? _onTapUp : null,
        onTapCancel: widget.onTap != null ? _onTapCancel : null,
        onTap: widget.onTap,
        child: GlassCard(
          borderRadius: widget.borderRadius,
          padding: widget.padding,
          animate: widget.animate,
          animationDelay: widget.animationDelay,
          color: widget.color,
          border: widget.border,
          child: widget.child,
        ),
      ),
    );
  }
}

class _FileCard extends StatefulWidget {
  final String filePath;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _FileCard({
    required this.filePath,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_FileCard> createState() => _FileCardState();
}

class _FileCardState extends State<_FileCard> with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnim;
  bool? _fileExists;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.96,
      upperBound: 1.0,
    );
    _scaleAnim = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    );
    _scaleController.value = 1.0;
    // Check file existence asynchronously instead of in build()
    Future.microtask(() async {
      _fileExists = await File(widget.filePath).exists();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap != null) {
      _scaleController.animateTo(0.96, duration: const Duration(milliseconds: 100), curve: Curves.easeOutCubic);
    }
  }

  void _onTapUp(TapUpDetails details) {
    _scaleController.animateTo(1.0, duration: const Duration(milliseconds: 150), curve: Curves.easeOutCubic);
  }

  void _onTapCancel() {
    _scaleController.animateTo(1.0, duration: const Duration(milliseconds: 150), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final tp = ThemeProvider.of(context);
    final theme = tp.currentTheme;

    final name = p.basename(widget.filePath);
    final fileTypeLabel = _getFileTypeLabel(widget.filePath);
    final exists = _fileExists ?? true; // Default to true until async check completes

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: Key(widget.filePath),
        direction: DismissDirection.endToStart,
        onDismissed: (_) { HapticFeedback.mediumImpact(); widget.onDismiss(); },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Colors.redAccent.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete_outline, color: Colors.white70),
        ),
        child: ScaleTransition(
          scale: _scaleAnim,
          child: GestureDetector(
            onTapDown: widget.onTap != null ? _onTapDown : null,
            onTapUp: widget.onTap != null ? _onTapUp : null,
            onTapCancel: widget.onTap != null ? _onTapCancel : null,
            onTap: widget.onTap,
            child: GlassCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: exists
                            ? [theme.primaryColor.withValues(alpha: 0.4), theme.accentColor.withValues(alpha: 0.2)]
                            : [Colors.redAccent.withValues(alpha: 0.3), Colors.red.withValues(alpha: 0.1)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      exists ? Icons.description_rounded : Icons.error_outline_rounded,
                      color: Colors.white70,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: exists
                                ? theme.textColor
                                : theme.textSecondary.withValues(alpha: 0.4),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                fileTypeLabel,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: theme.primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                p.dirname(widget.filePath),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: theme.textSecondary.withValues(alpha: 0.3),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded,
                      color: theme.textSecondary.withValues(alpha: 0.3), size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// SETTINGS PAGE
// ═══════════════════════════════════════════════════════════════════════

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // FIX: Wrap entire page in ValueListenableBuilder so theme/font/lineHeight
    // changes rebuild the whole page instantly without needing to leave and return.
    return ValueListenableBuilder<int>(
      valueListenable: globalThemeVersion,
      builder: (context, _, __) {
        final tp = ThemeProvider.of(context);
        final theme = tp.currentTheme;
        final isDark = theme.brightness == Brightness.dark;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: isDark
              ? const SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.light,
                )
              : const SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.dark,
                ),
          child: Scaffold(
            extendBody: true,
            extendBodyBehindAppBar: true,
            body: AnimatedGradientBg(
              child: SafeArea(
                child: Column(
                  children: [
                    // Top bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      child: GlassCard(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            _GlassIconButton(
                              icon: Icons.arrow_back_rounded,
                              onTap: () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.settings_rounded, color: theme.primaryColor, size: 22),
                            const SizedBox(width: 12),
                            Text(
                              '设置',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: theme.textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Settings content
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          20, 8, 20, MediaQuery.of(context).padding.bottom + 40,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Theme selection
                            _SectionTitle('主题风格'),
                            const SizedBox(height: 12),
                            Row(
                              children: AppThemeMode.values.map((mode) {
                                final t = _appThemes[mode]!;
                                final selected = tp.mode == mode;
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: _SettingsCard(
                                      onTap: () => tp.setTheme(mode),
                                      borderRadius: 14,
                                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                                      animate: true,
                                      animationDelay: Duration(milliseconds: mode.index * 60),
                                      color: selected
                                          ? t.primaryColor.withValues(alpha: 0.15)
                                          : null,
                                      border: Border.all(
                                        color: selected
                                            ? t.primaryColor.withValues(alpha: 0.5)
                                            : (isDark
                                                ? Colors.white.withValues(alpha: 0.1)
                                                : t.primaryColor.withValues(alpha: 0.08)),
                                        width: selected ? 1.5 : 1,
                                      ),
                                      child: Column(
                                        children: [
                                          // Color preview circle
                                          Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: t.bgGradientColors.length >= 2
                                                    ? [t.primaryColor, t.accentColor]
                                                    : [t.primaryColor, t.primaryColor],
                                              ),
                                              shape: BoxShape.circle,
                                              border: selected
                                                  ? Border.all(color: Colors.white, width: 2)
                                                  : null,
                                            ),
                                            child: selected
                                                ? const Icon(Icons.check, color: Colors.white, size: 18)
                                                : null,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            t.name,
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                              color: theme.textColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 28),

                            // Font size
                            _SectionTitle('字体大小'),
                            const SizedBox(height: 12),
                            Row(
                              children: FontSizeOption.values.map((opt) {
                                final selected = tp.fontSizeOption == opt;
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: _SettingsCard(
                                      onTap: () => tp.setFontSize(opt),
                                      borderRadius: 12,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      color: selected ? theme.primaryColor.withValues(alpha: 0.15) : null,
                                      border: Border.all(
                                        color: selected
                                            ? theme.primaryColor.withValues(alpha: 0.5)
                                            : (isDark
                                                ? Colors.white.withValues(alpha: 0.1)
                                                : theme.primaryColor.withValues(alpha: 0.08)),
                                        width: selected ? 1.5 : 1,
                                      ),
                                      child: Center(
                                        child: Text(
                                          _fontSizeLabels[opt]!,
                                          style: GoogleFonts.inter(
                                            fontSize: _fontSizeMap[opt]! - 2,
                                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                            color: selected ? theme.primaryColor : theme.textColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 28),

                            // Letter spacing
                            _SectionTitle('字间距'),
                            const SizedBox(height: 12),
                            Row(
                              children: [0.0, 0.5, 1.0, 2.0].map((sp) {
                                final selected = (tp.letterSpacing - sp).abs() < 0.01;
                                final label = sp == 0.0 ? '默认' : '${sp.toStringAsFixed(1)}';
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: _SettingsCard(
                                      onTap: () => tp.setLetterSpacing(sp),
                                      borderRadius: 12,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      color: selected ? theme.primaryColor.withValues(alpha: 0.15) : null,
                                      border: Border.all(
                                        color: selected
                                            ? theme.primaryColor.withValues(alpha: 0.5)
                                            : (isDark
                                                ? Colors.white.withValues(alpha: 0.1)
                                                : theme.primaryColor.withValues(alpha: 0.08)),
                                        width: selected ? 1.5 : 1,
                                      ),
                                      child: Center(
                                        child: Text(
                                          label,
                                          style: GoogleFonts.inter(
                                            fontSize: sp == 0.0 ? 12 : 13,
                                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                            color: selected ? theme.primaryColor : theme.textColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 28),

                            // Line height
                            _SectionTitle('行高'),
                            const SizedBox(height: 12),
                            Row(
                              children: [1.5, 1.75, 2.0].map((h) {
                                final selected = tp.lineHeight == h;
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: _SettingsCard(
                                      onTap: () => tp.setLineHeight(h),
                                      borderRadius: 12,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      color: selected ? theme.primaryColor.withValues(alpha: 0.15) : null,
                                      border: Border.all(
                                        color: selected
                                            ? theme.primaryColor.withValues(alpha: 0.5)
                                            : (isDark
                                                ? Colors.white.withValues(alpha: 0.1)
                                                : theme.primaryColor.withValues(alpha: 0.08)),
                                        width: selected ? 1.5 : 1,
                                      ),
                                      child: Center(
                                        child: Text(
                                          h.toString(),
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                            color: selected ? theme.primaryColor : theme.textColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 28),

                            // Preview
                            _SectionTitle('预览'),
                            const SizedBox(height: 12),
                            GlassCard(
                              borderRadius: 16,
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Heading 示例',
                                    style: GoogleFonts.inter(
                                      fontSize: tp.fontSize + 10,
                                      fontWeight: FontWeight.w700,
                                      color: theme.textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '这是一段正文文字，用于预览当前的字体大小和行高设置。琥珀 MD 阅读器支持多种主题风格，让你的阅读体验更加舒适。',
                                    style: GoogleFonts.inter(
                                      fontSize: tp.fontSize,
                                      color: theme.textSecondary,
                                      height: tp.lineHeight,
                                      letterSpacing: tp.letterSpacing,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: theme.primaryColor.withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'print("代码块示例")',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: tp.fontSize - 2,
                                        color: theme.primaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// SCALE ON TAP - 通用按下缩放反馈组件
// ═══════════════════════════════════════════════════════════════════════

class _ScaleOnTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleAmount;

  const _ScaleOnTap({
    required this.child,
    this.onTap,
    this.scaleAmount = 0.96,
  });

  @override
  State<_ScaleOnTap> createState() => _ScaleOnTapState();
}

class _ScaleOnTapState extends State<_ScaleOnTap> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: widget.scaleAmount,
      upperBound: 1.0,
    );
    _scaleAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _controller.value = 1.0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.animateTo(widget.scaleAmount, duration: const Duration(milliseconds: 100), curve: Curves.easeOutCubic);
  }

  void _onTapUp(TapUpDetails details) {
    _controller.animateTo(1.0, duration: const Duration(milliseconds: 150), curve: Curves.easeOutCubic);
  }

  void _onTapCancel() {
    _controller.animateTo(1.0, duration: const Duration(milliseconds: 150), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnim,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: widget.onTap,
        child: widget.child,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    final tp = ThemeProvider.of(context);
    final theme = tp.currentTheme;
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: theme.textSecondary.withValues(alpha: 0.6),
        letterSpacing: 1.2,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// READER PAGE
// ═══════════════════════════════════════════════════════════════════════

class ReaderPage extends StatefulWidget {
  final String filePath;
  final String fileType;
  const ReaderPage({super.key, required this.filePath, this.fileType = 'md'});

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  String _content = '';
  String _title = '';
  bool _loading = true;
  final ScrollController _scrollCtrl = ScrollController();
  bool _showBackToTop = false;
  Timer? _backToTopHideTimer;
  bool _showAppBar = true;
  double _lastScrollOffset = 0;
  double _scrollDeltaAccum = 0;
  Timer? _searchDebounceTimer;

  // Edit mode
  bool _isEditing = false;
  late TextEditingController _editController;

  // Search mode
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<int> _matchIndices = [];
  int _currentMatchIndex = -1;

  String get _fileType => widget.fileType;
  bool get _isMarkdown => _fileType == 'md';

  @override
  void initState() {
    super.initState();
    _title = p.basename(widget.filePath);
    _editController = TextEditingController();
    _loadFile();
    _scrollCtrl.addListener(() {
      final offset = _scrollCtrl.offset;
      final showFab = offset > 300;
      final delta = offset - _lastScrollOffset;
      bool needsUpdate = false;
      bool newShowAppBar = _showAppBar;

      // Back-to-top button
      if (showFab != _showBackToTop) {
        _showBackToTop = showFab;
        needsUpdate = true;
      }
      // Auto-hide back-to-top button after 1 second of no scrolling
      _backToTopHideTimer?.cancel();
      if (showFab) {
        _backToTopHideTimer = Timer(const Duration(seconds: 1), () {
          if (mounted && _showBackToTop) setState(() => _showBackToTop = false);
        });
      }

      // AppBar auto-hide on scroll down, show on scroll up
      if (delta > 0) {
        _scrollDeltaAccum = 0;
        if (offset > 60 && _showAppBar) {
          newShowAppBar = false;
          needsUpdate = true;
        }
      } else if (delta < 0) {
        _scrollDeltaAccum += delta.abs();
        if (offset < 200 || _scrollDeltaAccum > 100) {
          if (!_showAppBar) {
            newShowAppBar = true;
            needsUpdate = true;
          }
          _scrollDeltaAccum = 0;
        }
      }

      if (needsUpdate) {
        setState(() {
          _showAppBar = newShowAppBar;
        });
      }
      _lastScrollOffset = offset;
    });
    _searchController.addListener(() {
      // 防抖：300ms 后再执行搜索
      _searchDebounceTimer?.cancel();
      _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
        _performSearch(_searchController.text);
      });
    });
  }

  @override
  void dispose() {
    _backToTopHideTimer?.cancel();
    _searchDebounceTimer?.cancel();
    _scrollCtrl.dispose();
    _editController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFile() async {
    try {
      final file = File(widget.filePath);
      var content = await file.readAsString();

      // Format JSON
      if (_fileType == 'json') {
        try {
          final decoded = jsonDecode(content);
          const encoder = JsonEncoder.withIndent('  ');
          content = encoder.convert(decoded);
        } catch (_) {}
      }

      setState(() {
        _content = content;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _content = '# 读取失败\n\n无法读取文件:\n```\n$e\n```';
        _loading = false;
      });
    }
  }

  void _enterEditMode() {
    _editController.text = _content;
    setState(() => _isEditing = true);
  }

  void _exitEditMode() {
    setState(() => _isEditing = false);
  }

  Future<void> _saveFile() async {
    try {
      final file = File(widget.filePath);
      await file.writeAsString(_editController.text);
      setState(() {
        _content = _editController.text;
        _isEditing = false;
      });
      if (mounted) {
        final tp = ThemeProvider.of(context);
        final theme = tp.currentTheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('文件已保存', style: GoogleFonts.inter(color: Colors.white)),
            backgroundColor: theme.primaryColor.withValues(alpha: 0.8),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e', style: GoogleFonts.inter(color: Colors.white)),
            backgroundColor: Colors.redAccent.withValues(alpha: 0.8),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchQuery = '';
        _matchIndices = [];
        _currentMatchIndex = -1;
        _searchController.clear();
      }
    });
  }

  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchQuery = '';
        _matchIndices = [];
        _currentMatchIndex = -1;
      });
      return;
    }
    final lowerContent = _content.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final indices = <int>[];
    int start = 0;
    while (true) {
      final idx = lowerContent.indexOf(lowerQuery, start);
      if (idx == -1) break;
      indices.add(idx);
      start = idx + 1;
    }
    setState(() {
      _searchQuery = query;
      _matchIndices = indices;
      _currentMatchIndex = indices.isNotEmpty ? 0 : -1;
    });
    // Auto-scroll to first match
    if (indices.isNotEmpty) {
      _scrollToMatch(0);
    }
  }

  void _scrollToMatch(int matchListIndex) {
    if (_matchIndices.isEmpty || matchListIndex < 0 || matchListIndex >= _matchIndices.length) return;
    final charIndex = _matchIndices[matchListIndex];
    final totalChars = _content.length;
    if (totalChars == 0) return;

    // Estimate scroll position by character ratio
    final ratio = charIndex / totalChars;
    final maxScroll = _scrollCtrl.position.maxScrollExtent;
    final targetOffset = (ratio * maxScroll).clamp(0.0, maxScroll);

    _scrollCtrl.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _nextMatch() {
    if (_matchIndices.isEmpty) return;
    final newIdx = (_currentMatchIndex + 1) % _matchIndices.length;
    setState(() => _currentMatchIndex = newIdx);
    _scrollToMatch(newIdx);
  }

  void _prevMatch() {
    if (_matchIndices.isEmpty) return;
    final newIdx = (_currentMatchIndex - 1 + _matchIndices.length) % _matchIndices.length;
    setState(() => _currentMatchIndex = newIdx);
    _scrollToMatch(newIdx);
  }

  Widget _buildHighlightedMarkdown({double topPadding = 72}) {
    final tp = ThemeProvider.of(context);
    final theme = tp.currentTheme;
    final isDark = theme.brightness == Brightness.dark;

    if (_searchQuery.isEmpty || _matchIndices.isEmpty || !_isMarkdown) {
      // Plain rendering
      if (_isMarkdown) {
        return Markdown(
          key: ValueKey('md_${globalThemeVersion.value}'),
          data: _content,
          controller: _scrollCtrl,
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.of(context).padding.top + topPadding + (_isSearching ? 56 : 0),
            20,
            MediaQuery.of(context).padding.bottom + 32,
          ),
          selectable: true,
          styleSheet: _buildMarkdownStyleSheet(context),
        );
      } else {
        // Non-markdown: plain text display
        return SingleChildScrollView(
          controller: _scrollCtrl,
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.of(context).padding.top + topPadding + (_isSearching ? 56 : 0),
            20,
            MediaQuery.of(context).padding.bottom + 32,
          ),
          child: SelectableText(
            _content,
            style: GoogleFonts.jetBrainsMono(
              fontSize: tp.fontSize,
              color: theme.textSecondary,
              height: tp.lineHeight,
            ),
          ),
        );
      }
    }

    // Search-highlighted markdown: prefix matching lines with a subtle marker
    // Avoids breaking blockquotes, tables, code blocks etc.
    final lowerQuery = _searchQuery.toLowerCase();
    String highlightedContent = _content;

    if (_searchQuery.isNotEmpty) {
      final lines = _content.split('\n');
      final processedLines = <String>[];
      bool inCodeBlock = false;
      for (final line in lines) {
        if (line.trimLeft().startsWith('```')) {
          inCodeBlock = !inCodeBlock;
          processedLines.add(line);
          continue;
        }
        if (inCodeBlock || line.startsWith('|')) {
          // Don't highlight inside code blocks or tables
          processedLines.add(line);
        } else if (line.toLowerCase().contains(lowerQuery)) {
          // Add a subtle marker before the line content
          processedLines.add('🔍 $line');
        } else {
          processedLines.add(line);
        }
      }
      highlightedContent = processedLines.join('\n');
    }

    return Markdown(
      key: ValueKey('md_search_${globalThemeVersion.value}'),
      data: highlightedContent,
      controller: _scrollCtrl,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + topPadding + 56,
        20,
        MediaQuery.of(context).padding.bottom + 32,
      ),
      selectable: true,
      styleSheet: _buildMarkdownStyleSheet(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen to global theme changes for instant updates
    return ValueListenableBuilder<int>(
      valueListenable: globalThemeVersion,
      builder: (context, _, __) {
        final tp = ThemeProvider.of(context);
        final theme = tp.currentTheme;
        final isDark = theme.brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
            )
          : const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
            ),
      child: Scaffold(
        extendBody: true,
        extendBodyBehindAppBar: true,
        body: AnimatedGradientBg(
          child: _loading
              ? Center(
                  child: ShimmerSweep(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: theme.primaryColor.withValues(alpha: 0.2)),
                      ),
                      child: FadeTransition(
                        opacity: AlwaysStoppedAnimation(1.0),
                        child: CircularProgressIndicator(
                          color: theme.primaryColor,
                          strokeWidth: 3,
                        ),
                      ),
                    ),
                  ),
                )
              : Stack(
                  children: [
                    // Content
                    SafeArea(
                      top: false,
                      bottom: false,
                      child: _isEditing
                          ? const SizedBox()
                          : _buildHighlightedMarkdown(),
                    ),

                    // Edit mode overlay
                    if (_isEditing)
                      SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            MediaQuery.of(context).padding.top + 72,
                            16,
                            MediaQuery.of(context).padding.bottom + 16,
                          ),
                          child: GlassCard(
                            borderRadius: 16,
                            padding: EdgeInsets.zero,
                            color: isDark
                                ? const Color(0xFF0D0D1A).withValues(alpha: 0.85)
                                : Colors.white.withValues(alpha: 0.85),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : theme.primaryColor.withValues(alpha: 0.12),
                            ),
                            child: TextField(
                              controller: _editController,
                              maxLines: null,
                              expands: true,
                              textAlignVertical: TextAlignVertical.top,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: tp.fontSize,
                                color: theme.textSecondary,
                                height: tp.lineHeight,
                              ),
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.all(16),
                                border: InputBorder.none,
                                hintText: '在此编辑内容...',
                                hintStyle: GoogleFonts.inter(
                                  color: theme.textSecondary.withValues(alpha: 0.3),
                                ),
                              ),
                              cursorColor: theme.primaryColor,
                            ),
                          ),
                        ),
                      ),

                    // Top bar with smooth animation
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutQuint,
                      top: _showAppBar ? 0 : -(MediaQuery.of(context).padding.top + 72),
                      left: 0,
                      right: 0,
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                          child: _AppBarCard(
                            child: _isEditing
                                ? _buildEditAppBar()
                                : _isSearching
                                    ? _buildSearchAppBar()
                                    : _buildNormalAppBar(),
                          ),
                        ),
                      ),
                    ),

                    // Back to top FAB - with bounce entrance animation
                    Positioned(
                      bottom: MediaQuery.of(context).padding.bottom + 24,
                      right: 20,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        switchInCurve: Curves.elasticOut,
                        switchOutCurve: Curves.easeInBack,
                        transitionBuilder: (child, anim) {
                          return FadeTransition(
                            opacity: anim,
                            child: ScaleTransition(
                              scale: Tween<double>(begin: 0.3, end: 1.0).animate(
                                CurvedAnimation(parent: anim, curve: Curves.elasticOut),
                              ),
                              child: child,
                            ),
                          );
                        },
                        child: _showBackToTop && !_isEditing
                            ? _GlassFAB(
                                key: const ValueKey('back_to_top'),
                                onTap: () {
                                  _backToTopHideTimer?.cancel();
                                  _scrollCtrl.animateTo(
                                    0,
                                    duration: const Duration(milliseconds: 500),
                                    curve: Curves.easeOut,
                                  );
                                  setState(() => _showBackToTop = false);
                                },
                                child: const SizedBox(
                                  width: 52,
                                  height: 52,
                                  child: Icon(Icons.keyboard_arrow_up_rounded,
                                      color: Colors.white, size: 28),
                                ),
                              )
                            : const SizedBox.shrink(key: ValueKey('no_back_to_top')),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
      },
    );
  }

  Widget _buildNormalAppBar() {
    final tp = ThemeProvider.of(context);
    final theme = tp.currentTheme;

    return Row(
      children: [
        _GlassIconButton(
          icon: Icons.arrow_back_rounded,
          onTap: () => Navigator.pop(context),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _title,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: theme.textColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (!_isMarkdown)
                Text(
                  _getFileTypeLabel(widget.filePath),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: theme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        _GlassIconButton(
          icon: Icons.search_rounded,
          onTap: _toggleSearch,
        ),
        const SizedBox(width: 4),
        _GlassIconButton(
          icon: Icons.edit_rounded,
          onTap: _enterEditMode,
        ),
      ],
    );
  }

  Widget _buildEditAppBar() {
    final tp = ThemeProvider.of(context);
    final theme = tp.currentTheme;

    return Row(
      children: [
        _GlassIconButton(
          icon: Icons.close_rounded,
          onTap: _exitEditMode,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFD54F),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '编辑中',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: theme.textColor,
                ),
              ),
            ],
          ),
        ),
        _ScaleOnTap(
          scaleAmount: 0.94,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Material(
                color: theme.primaryColor.withValues(alpha: 0.3),
                child: InkWell(
                  onTap: _saveFile,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.save_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          '保存',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAppBar() {
    final tp = ThemeProvider.of(context);
    final theme = tp.currentTheme;
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        Row(
          children: [
            _GlassIconButton(
              icon: Icons.close_rounded,
              onTap: _toggleSearch,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : theme.primaryColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.inter(fontSize: 14, color: theme.textColor),
                  decoration: InputDecoration(
                    hintText: '搜索...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 14,
                      color: theme.textSecondary.withValues(alpha: 0.4),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  cursorColor: theme.primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _matchIndices.isEmpty
                  ? '无匹配'
                  : '${_currentMatchIndex + 1}/${_matchIndices.length}',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: theme.textSecondary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 4),
            _GlassIconButton(
              icon: Icons.keyboard_arrow_up_rounded,
              onTap: _prevMatch,
            ),
            const SizedBox(width: 2),
            _GlassIconButton(
              icon: Icons.keyboard_arrow_down_rounded,
              onTap: _nextMatch,
            ),
          ],
        ),
      ],
    );
  }

  MarkdownStyleSheet _buildMarkdownStyleSheet(BuildContext context) {
    final tp = ThemeProvider.of(context);
    final theme = tp.currentTheme;
    final fs = tp.fontSize;
    final lh = tp.lineHeight;
    final ls = tp.letterSpacing;
    final isDark = theme.brightness == Brightness.dark;
    final isAurora = theme.id == 'aurora';

    // Body text color
    final bodyColor = isAurora
        ? const Color(0xFFC8F0DC)
        : isDark
            ? theme.textSecondary
            : const Color(0xFF334155); // universal light theme text
    // Heading color
    final headingColor = isAurora
        ? const Color(0xFFE8FFF4)
        : isDark
            ? theme.textColor
            : const Color(0xFF1E293B); // universal light heading
    // Strong/bold color
    final strongColor = isAurora
        ? const Color(0xFFFFFFFF)
        : isDark
            ? theme.textColor
            : const Color(0xFF1E293B);
    // Inline code text color
    final codeTextColor = isAurora
        ? const Color(0xFF6EE7B7)
        : isDark
            ? const Color(0xFFCE93D8)
            : theme.primaryColor;
    // Link color
    final linkColor = isAurora
        ? const Color(0xFFA5F3C4)
        : isDark
            ? const Color(0xFF64B5F6)
            : theme.primaryColor;
    // Inline code background
    final codeBgColor = isAurora
        ? const Color(0xFF6EE7B7).withValues(alpha: 0.08)
        : isDark
            ? Colors.white.withValues(alpha: 0.06)
            : theme.primaryColor.withValues(alpha: 0.07);
    // Code block background
    final codeBlockBgColor = isAurora
        ? const Color(0xFF0A1929).withValues(alpha: 0.85)
        : isDark
            ? theme.primaryColor.withValues(alpha: 0.04)
            : const Color(0xFFF8FAFC);
    // Code block border
    final codeBlockBorderColor = isAurora
        ? const Color(0xFF6EE7B7).withValues(alpha: 0.15)
        : isDark
            ? theme.primaryColor.withValues(alpha: 0.08)
            : theme.primaryColor.withValues(alpha: 0.10);
    // Blockquote border
    final blockquoteBorderColor = isAurora
        ? const Color(0xFF818CF8).withValues(alpha: 0.5)
        : theme.primaryColor.withValues(alpha: 0.4);
    // Blockquote background
    final blockquoteBgColor = isAurora
        ? const Color(0xFF818CF8).withValues(alpha: 0.06)
        : theme.primaryColor.withValues(alpha: 0.04);
    // Blockquote text
    final blockquoteTextColor = isAurora
        ? const Color(0xFFC0D0F0)
        : isDark
            ? theme.textSecondary.withValues(alpha: 0.7)
            : const Color(0xFF475569);
    // Bullet color
    final bulletColor = isAurora
        ? const Color(0xFF6EE7B7)
        : theme.primaryColor;
    // H3 color (accent)
    final h3Color = isAurora
        ? const Color(0xFF818CF8)
        : isDark
            ? theme.accentColor
            : theme.primaryColor;
    // H4 color
    final h4Color = isAurora
        ? const Color(0xFF6EE7B7)
        : theme.primaryColor;
    // Table header color
    final tableHeadColor = isAurora
        ? const Color(0xFFE8FFF4)
        : isDark
            ? theme.textColor
            : const Color(0xFF1E293B);
    // Table body color
    final tableBodyColor = isAurora
        ? const Color(0xFFC8F0DC)
        : isDark
            ? theme.textSecondary
            : const Color(0xFF334155);

    return MarkdownStyleSheet(
      h1: GoogleFonts.inter(
        fontSize: fs + 13,
        fontWeight: FontWeight.w800,
        color: headingColor,
        height: 1.4,
      ).copyWith(shadows: isAurora
          ? [
              Shadow(color: const Color(0xFF6EE7B7).withValues(alpha: 0.35), blurRadius: 28),
              Shadow(color: const Color(0xFF818CF8).withValues(alpha: 0.15), blurRadius: 40),
            ]
          : [
              Shadow(color: theme.primaryColor.withValues(alpha: 0.15), blurRadius: 12),
            ]),
      h2: GoogleFonts.inter(
        fontSize: fs + 7,
        fontWeight: FontWeight.w700,
        color: headingColor,
        height: 1.4,
      ),
      h3: GoogleFonts.inter(
        fontSize: fs + 3,
        fontWeight: FontWeight.w700,
        color: h3Color,
        height: 1.4,
      ),
      h4: GoogleFonts.inter(
        fontSize: fs + 1,
        fontWeight: FontWeight.w600,
        color: h4Color,
        height: 1.4,
      ),
      p: GoogleFonts.inter(
        fontSize: fs,
        height: lh,
        letterSpacing: ls,
        color: bodyColor,
      ),
      strong: GoogleFonts.inter(
        fontSize: fs,
        fontWeight: FontWeight.w700,
        color: strongColor,
      ),
      em: GoogleFonts.inter(
        fontSize: fs,
        fontStyle: FontStyle.italic,
        color: bodyColor,
      ),
      a: GoogleFonts.inter(
        color: linkColor,
        fontSize: fs,
        decoration: TextDecoration.underline,
        decorationColor: linkColor.withValues(alpha: 0.4),
      ),
      code: GoogleFonts.jetBrainsMono(
        fontSize: fs - 2,
        color: codeTextColor,
        backgroundColor: codeBgColor,
      ),
      codeblockDecoration: BoxDecoration(
        color: codeBlockBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: codeBlockBorderColor),
      ),
      codeblockPadding: const EdgeInsets.all(16),
      blockquote: GoogleFonts.inter(
        fontSize: fs - 1,
        color: blockquoteTextColor,
        fontStyle: FontStyle.italic,
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: blockquoteBorderColor, width: 3),
        ),
        color: blockquoteBgColor,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      blockquotePadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      listBullet: GoogleFonts.inter(
        fontSize: fs,
        color: bulletColor,
      ),
      listIndent: 24,
      tableHead: GoogleFonts.inter(
        fontSize: fs - 2,
        fontWeight: FontWeight.w700,
        color: tableHeadColor,
      ),
      tableBody: GoogleFonts.inter(
        fontSize: fs - 2,
        color: tableBodyColor,
      ),
      tableBorder: TableBorder.all(
        color: theme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      tableCellsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.primaryColor.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// NETWORK STORAGE PAGE (SMB / WebDAV) — with real WebDAV connection
// ═══════════════════════════════════════════════════════════════════════

class NetworkStoragePage extends StatefulWidget {
  final String storageType;
  const NetworkStoragePage({super.key, required this.storageType});

  @override
  State<NetworkStoragePage> createState() => _NetworkStoragePageState();
}

class _NetworkStoragePageState extends State<NetworkStoragePage> with TickerProviderStateMixin {
  bool _connected = false;
  bool _connecting = false;
  String? _error;
  bool _rememberPassword = true;

  // Animation controllers
  late AnimationController _connectionAnimController;
  late Animation<double> _connectionAnim;
  late AnimationController _fileListAnimController;
  late Animation<double> _fileListAnim;
  late AnimationController _errorAnimController;
  late Animation<Offset> _errorAnim;

  // WebDAV fields
  final _webdavUrl = TextEditingController();
  final _webdavUser = TextEditingController();
  final _webdavPass = TextEditingController();
  String _webdavBaseUrl = '';
  String _webdavUserAuth = '';
  String _webdavPassAuth = '';
  String _currentPath = '/';

  final List<_RemoteFile> _files = [];

  @override
  void initState() {
    super.initState();
    
    // Connection state animation
    _connectionAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _connectionAnim = CurvedAnimation(
      parent: _connectionAnimController,
      curve: Curves.easeInOut,
    );
    
    // File list fade in animation
    _fileListAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fileListAnim = CurvedAnimation(
      parent: _fileListAnimController,
      curve: Curves.easeOutCubic,
    );
    
    // Error shake animation
    _errorAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _errorAnim = TweenSequence<Offset>([
      TweenSequenceItem(tween: Tween<Offset>(begin: Offset.zero, end: const Offset(0.05, 0)), weight: 2),
      TweenSequenceItem(tween: Tween<Offset>(begin: const Offset(0.05, 0), end: const Offset(-0.05, 0)), weight: 2),
      TweenSequenceItem(tween: Tween<Offset>(begin: const Offset(-0.05, 0), end: const Offset(0.05, 0)), weight: 2),
      TweenSequenceItem(tween: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero), weight: 2),
    ]).animate(CurvedAnimation(parent: _errorAnimController, curve: Curves.easeInOut));
    
    _loadSavedWebdavInfo();
  }

  Future<void> _loadSavedWebdavInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('webdav_url') ?? '';
    final savedUser = prefs.getString('webdav_username') ?? '';
    final savedPass = prefs.getString('webdav_password') ?? '';
    final savedRemember = prefs.getBool('webdav_remember') ?? true;
    if (savedUrl.isNotEmpty) {
      _webdavUrl.text = savedUrl;
      _webdavUser.text = savedUser;
      _webdavPass.text = savedPass;
      _rememberPassword = savedRemember;
      if (mounted) setState(() {});
    }
  }

  Future<void> _saveWebdavInfo() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberPassword) {
      await prefs.setString('webdav_url', _webdavUrl.text.trim());
      await prefs.setString('webdav_username', _webdavUser.text.trim());
      await prefs.setString('webdav_password', _webdavPass.text);
    }
    await prefs.setBool('webdav_remember', _rememberPassword);
  }

  Future<void> _clearSavedWebdavInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('webdav_url');
    await prefs.remove('webdav_username');
    await prefs.remove('webdav_password');
    await prefs.remove('webdav_remember');
    _webdavUrl.clear();
    _webdavUser.clear();
    _webdavPass.clear();
    _rememberPassword = true;
    setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已清除保存的连接信息', style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: Colors.redAccent.withValues(alpha: 0.8),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  void dispose() {
    _webdavUrl.dispose();
    _webdavUser.dispose();
    _webdavPass.dispose();
    _connectionAnimController.dispose();
    _fileListAnimController.dispose();
    _errorAnimController.dispose();
    super.dispose();
  }

  String get _typeLabel => 'WebDAV';
  IconData get _typeIcon => Icons.cloud_rounded;
  Color get _typeColor => ThemeProvider.of(context).currentTheme.primaryColor;

  Future<void> _connect() async {
    setState(() {
      _connecting = true;
      _error = null;
    });
    _errorAnimController.reset();

    try {
      debugPrint('[WebDAV] 开始连接: $_webdavUrl.text');
      await _connectWebdav();
      debugPrint('[WebDAV] 连接成功，文件列表: ${_files.length}');
      await _saveWebdavInfo();
      if (mounted) {
        // 先显示文件列表动画
        _fileListAnimController.forward(from: 0);
        setState(() {
          _connecting = false;
          _connected = true;
        });
        debugPrint('[WebDAV] UI 状态已更新: _connected = true');
      }
    } catch (e, stackTrace) {
      debugPrint('[WebDAV] 连接失败: $e');
      debugPrint('[WebDAV] 堆栈: $stackTrace');
      String errorMsg;
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (msg.contains('Failed host lookup') || msg.contains('DNS') || msg.contains('无法解析')) {
        errorMsg = '无法解析服务器地址，请检查域名是否正确或网络连接';
      } else if (msg.contains('timed out') || msg.contains('Timeout') || msg.contains('超时')) {
        errorMsg = '连接超时，请检查服务器地址和网络连接';
      } else if (msg.contains('认证失败') || msg.contains('401') || msg.contains('403')) {
        errorMsg = '用户名或密码错误，请重新输入';
      } else if (msg.contains('Connection refused') || msg.contains('拒绝')) {
        errorMsg = '服务器拒绝连接，请检查端口或服务是否启动';
      } else {
        errorMsg = msg;
      }
      if (mounted) {
        setState(() {
          _connecting = false;
          _connected = false;
          _error = errorMsg;
        });
        // 触发动画
        _errorAnimController.forward(from: 0);
        debugPrint('[WebDAV] UI 状态已更新: _connected = false, error = $errorMsg');
      }
    }
  }

  Future<void> _connectWebdav() async {
    var url = _webdavUrl.text.trim();
    final user = _webdavUser.text.trim();
    final pass = _webdavPass.text;

    if (url.isEmpty) throw Exception('请输入服务器地址');

    // Auto-prepend scheme if missing (default to http for compatibility)
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }

    // Remove trailing slash
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);

    // Validate URL
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) {
      throw Exception('服务器地址格式不正确，请检查输入');
    }

    debugPrint('[WebDAV] 连接参数: URL=$url, User=$user, Pass=${pass.isEmpty ? "(空)" : "已设置"}');

    _webdavBaseUrl = url;
    _webdavUserAuth = user;
    _webdavPassAuth = pass;

    try {
      // Test connection with PROPFIND on root
      debugPrint('[WebDAV] 发送 PROPFIND 请求到根目录 /');
      final list = await _webdavPropfind('/');
      debugPrint('[WebDAV] PROPFIND 响应: 获取到 ${list.length} 个文件/目录');
      _files.clear();
      _files.addAll(list);
      _currentPath = '/';
    } on SocketException catch (e) {
      debugPrint('[WebDAV] SocketException: ${e.message}');
      if (e.message.contains('Failed host lookup')) {
        throw Exception('无法解析服务器地址，请检查域名是否正确或网络连接');
      } else if (e.message.contains('Connection refused')) {
        throw Exception('服务器拒绝连接，请检查端口是否正确');
      }
      throw Exception('网络连接失败: ${e.message}');
    } on TimeoutException {
      throw Exception('连接超时，请检查服务器地址和网络');
    } on Exception catch (e) {
      final msg = e.toString();
      debugPrint('[WebDAV] Exception: $msg');
      if (msg.contains('TimeoutException') || msg.contains('超时')) {
        throw Exception('连接超时，请检查服务器地址和网络');
      }
      if (msg.contains('401') || msg.contains('403') || msg.contains('认证')) {
        throw Exception('用户名或密码错误，请重新输入');
      }
      rethrow;
    }
  }

  /// WebDAV PROPFIND request using dart:io HttpClient
  /// v5.4: Complete rewrite — bypasses http package for full control over PROPFIND method
  Future<List<_RemoteFile>> _webdavPropfind(String path) async {
    final auth = base64Encode(utf8.encode('$_webdavUserAuth:$_webdavPassAuth'));

    // Build the target URL string directly (no double-encoding issues)
    final baseUri = Uri.parse(_webdavBaseUrl);
    final basePath = baseUri.path.endsWith('/') ? baseUri.path.substring(0, baseUri.path.length - 1) : baseUri.path;
    final dirPath = path.startsWith('/') ? path : '/$path';
    final fullPath = basePath + dirPath;

    // Build URL with proper encoding — only encode path segments
    final encodedSegments = fullPath.split('/')
        .map((s) => s.isEmpty ? s : Uri.encodeComponent(s))
        .join('/');
    final requestUrl = '${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}$encodedSegments';

    debugPrint('[WebDAV PROPFIND] URL: $requestUrl');
    debugPrint('[WebDAV PROPFIND] User: ${_webdavUserAuth.isEmpty ? "(空)" : "已设置"}');

    final propfindXml = '<?xml version="1.0" encoding="utf-8"?>'
        '<D:propfind xmlns:D="DAV:">'
        '<D:prop><D:displayname/><D:resourcetype/>'
        '</D:prop></D:propfind>';

    final client = HttpClient();
    try {
      // Follow redirects manually
      String currentUrl = requestUrl;
      int redirectCount = 0;
      const maxRedirects = 5;

      while (true) {
        final uri = Uri.parse(currentUrl);
        final req = await client.openUrl('PROPFIND', uri)
            .timeout(const Duration(seconds: 15));
        req.headers.set('Authorization', 'Basic $auth');
        req.headers.set('Depth', '1');
        req.headers.set('Content-Type', 'application/xml; charset=utf-8');
        req.headers.set('Content-Length', '${utf8.encode(propfindXml).length}');
        req.write(propfindXml);

        final resp = await req.close().timeout(const Duration(seconds: 15));

        debugPrint('[WebDAV PROPFIND] Status: ${resp.statusCode}');

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
          debugPrint('[WebDAV PROPFIND] Redirect #$redirectCount → $location');
          // Handle relative redirects
          if (location.startsWith('/')) {
            currentUrl = '${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}$location';
          } else {
            currentUrl = location;
          }
          continue;
        }

        if (resp.statusCode >= 400) {
          final body = await resp.transform(utf8.decoder).join();
          debugPrint('[WebDAV PROPFIND] Error ${resp.statusCode}: ${body.substring(0, body.length > 200 ? 200 : body.length)}');
          throw Exception('服务器返回错误: ${resp.statusCode}');
        }

        // Read response body
        final body = await resp.transform(utf8.decoder).join();
        debugPrint('[WebDAV PROPFIND] Body length: ${body.length}');

        if (resp.statusCode != 207) {
          throw Exception('服务器响应异常: HTTP ${resp.statusCode}');
        }

        if (!body.contains('multistatus') && !body.contains('response')) {
          throw Exception('服务器返回了无效的WebDAV响应');
        }

        return _parsePropfindResponse(body, path);
      }
    } on SocketException catch (e) {
      debugPrint('[WebDAV PROPFIND] SocketException: ${e.message}');
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

  /// Parse PROPFIND XML response
  List<_RemoteFile> _parsePropfindResponse(String xml, String requestPath) {
    final files = <_RemoteFile>[];

    // Extract all <D:response>...</D:response> blocks using a more robust regex
    final responseRegex = RegExp(r'<[a-zA-Z0-9:]+response[^>]*>(.*?)</[a-zA-Z0-9:]+response>', dotAll: true);
    final matches = responseRegex.allMatches(xml);

    debugPrint('[WebDAV 解析] 找到 ${matches.length} 个 response 块');

    for (final match in matches) {
      final resp = match.group(1)!;

      // Check if it's a directory — handles <D:collection/>, <D:collection></D:collection>, etc.
      var isDir = RegExp(r'<[a-zA-Z0-9:]+collection\s*/\s*>', dotAll: true).hasMatch(resp) ||
          RegExp(r'<[a-zA-Z0-9:]+collection[^>]*>\s*</[a-zA-Z0-9:]+collection>', dotAll: true).hasMatch(resp);

      // Extract href first (needed for directory detection and name extraction)
      final hrefMatch = RegExp(r'<[a-zA-Z0-9:]+href[^>]*>([^<]*)</[a-zA-Z0-9:]+href>').firstMatch(resp);
      if (hrefMatch == null) continue;

      var rawHref = Uri.decodeFull(hrefMatch.group(1)!.trim());

      // Fallback: use href to detect directory if collection tag not found
      if (!isDir) {
        isDir = rawHref.endsWith('/');
      }

      // Extract displayname
      final nameMatch = RegExp(r'<[a-zA-Z0-9:]+displayname[^>]*>([^<]*)</[a-zA-Z0-9:]+displayname>').firstMatch(resp);

      String name;
      if (nameMatch != null && nameMatch.group(1)!.trim().isNotEmpty) {
        name = nameMatch.group(1)!.trim();
      } else {
        // Fallback: extract name from href
        var href = rawHref;
        // Remove trailing slash for directories
        if (href.endsWith('/')) href = href.substring(0, href.length - 1);
        // Get the last non-empty path segment
        final segments = href.split('/').where((s) => s.isNotEmpty).toList();
        name = segments.isNotEmpty ? segments.last : '';
      }

      if (name.isEmpty || name == '.') continue;

      // Build the expected full URL path to skip the directory itself
      final baseUri = Uri.parse(_webdavBaseUrl);
      final basePath = baseUri.path.endsWith('/') ? baseUri.path.substring(0, baseUri.path.length - 1) : baseUri.path;
      final normalizedReqPath = (basePath + requestPath).endsWith('/')
          ? (basePath + requestPath).substring(0, (basePath + requestPath).length - 1)
          : (basePath + requestPath);
      final normalizedHref = rawHref.endsWith('/') ? rawHref.substring(0, rawHref.length - 1) : rawHref;

      // Skip if this entry is the requested directory itself
      if (normalizedHref == normalizedReqPath || normalizedHref == baseUri.path || normalizedHref.isEmpty) {
        debugPrint('[WebDAV 解析] 跳过自身目录: $normalizedHref');
        continue;
      }

      debugPrint('[WebDAV 解析] 文件: $name, 目录: $isDir');
      files.add(_RemoteFile(name, isDir));
    }

    // Sort: directories first, then alphabetically
    files.sort((a, b) {
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;
      return a.name.compareTo(b.name);
    });

    return files;
  }

  /// WebDAV GET request to download a file using dart:io HttpClient
  /// v5.4: Rewritten for consistency with PROPFIND
  Future<void> _webdavGet(String remotePath, String localPath) async {
    final auth = base64Encode(utf8.encode('$_webdavUserAuth:$_webdavPassAuth'));

    final baseUri = Uri.parse(_webdavBaseUrl);
    final basePath = baseUri.path.endsWith('/') ? baseUri.path.substring(0, baseUri.path.length - 1) : baseUri.path;
    final filePath = remotePath.startsWith('/') ? remotePath : '/$remotePath';
    final fullPath = basePath + filePath;
    final encodedSegments = fullPath.split('/')
        .map((s) => s.isEmpty ? s : Uri.encodeComponent(s))
        .join('/');
    final requestUrl = '${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}$encodedSegments';

    debugPrint('[WebDAV GET] URL: $requestUrl');

    final client = HttpClient();
    try {
      final uri = Uri.parse(requestUrl);
      final req = await client.getUrl(uri).timeout(const Duration(seconds: 15));
      req.headers.set('Authorization', 'Basic $auth');
      req.headers.set('Accept', '*/*');

      final resp = await req.close().timeout(const Duration(seconds: 30));
      debugPrint('[WebDAV GET] Status: ${resp.statusCode}');

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
      debugPrint('[WebDAV GET] Download complete: $localPath');
    } finally {
      client.close();
    }
  }

  Future<void> _navigateDir(String dirName) async {
    final newPath = _currentPath.endsWith('/')
        ? '$_currentPath$dirName'
        : '$_currentPath/$dirName';
    try {
      final list = await _webdavPropfind(newPath);
      _files.clear();
      _files.addAll(list);
      setState(() => _currentPath = newPath.endsWith('/') ? newPath : '$newPath/');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法打开文件夹: $e')),
        );
      }
    }
  }

  Future<void> _downloadAndOpen(_RemoteFile file) async {
    try {
      final remotePath = _currentPath.endsWith('/')
          ? '$_currentPath${file.name}'
          : '$_currentPath/${file.name}';

      final dir = await getApplicationDocumentsDirectory();
      final localPath = '${dir.path}/${file.name}';
      await _webdavGet(remotePath, localPath);

      if (mounted) {
        Navigator.pushNamed(context, '/reader', arguments: {
          'path': localPath,
          'fileType': _getFileType(file.name),
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败: $e')),
        );
      }
    }
  }

  void _disconnect() {
    _webdavBaseUrl = '';
    _webdavUserAuth = '';
    _webdavPassAuth = '';
    setState(() {
      _connected = false;
      _files.clear();
      _currentPath = '/';
    });
  }

  Future<void> _goUpDir() async {
    if (_currentPath == '/') return;
    final parts = _currentPath.split('/')..removeWhere((s) => s.isEmpty);
    if (parts.isEmpty) {
      setState(() => _currentPath = '/');
    } else {
      parts.removeLast();
      final parentPath = '/${parts.join('/')}/';
      try {
        final list = await _webdavPropfind(parentPath);
        _files.clear();
        _files.addAll(list);
        setState(() => _currentPath = parentPath);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('无法打开上级目录: $e', style: GoogleFonts.inter(color: Colors.white)),
              backgroundColor: Colors.redAccent.withValues(alpha: 0.8),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // FIX: Wrap in ValueListenableBuilder for theme consistency
    return ValueListenableBuilder<int>(
      valueListenable: globalThemeVersion,
      builder: (context, _, __) {
        final tp = ThemeProvider.of(context);
        final theme = tp.currentTheme;
        final isDark = theme.brightness == Brightness.dark;

      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: isDark
            ? const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
              )
            : const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.dark,
              ),
        child: Scaffold(
        extendBody: true,
        extendBodyBehindAppBar: true,
        body: AnimatedGradientBg(
          child: SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        _GlassIconButton(
                          icon: Icons.arrow_back_rounded,
                          onTap: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [_typeColor.withValues(alpha: 0.5), _typeColor.withValues(alpha: 0.2)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(_typeIcon, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '$_typeLabel 连接',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: theme.textColor,
                            ),
                          ),
                        ),
                        if (_connected)
                          _GlassIconButton(
                            icon: Icons.link_off_rounded,
                            onTap: _disconnect,
                          ),
                      ],
                    ),
                  ),
                ),
                // Error message with shake animation
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _error != null
                      ? SlideTransition(
                          position: _errorAnim,
                          child: FadeTransition(
                            opacity: _errorAnimController.drive(
                              CurveTween(curve: const Interval(0, 0.5, curve: Curves.easeIn)),
                            ),
                            child: Padding(
                              key: const ValueKey('error'),
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: GlassCard(
                                borderRadius: 12,
                                padding: const EdgeInsets.all(12),
                                color: Colors.redAccent.withValues(alpha: 0.1),
                                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _error!,
                                        style: GoogleFonts.inter(fontSize: 12, color: Colors.redAccent),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(key: ValueKey('no_error')),
                ),
                // Body with AnimatedSwitcher for config/file list transition
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    switchInCurve: Curves.easeInOut,
                    switchOutCurve: Curves.easeInOut,
                    child: _connected 
                        ? _buildFileList()
                        : _buildConfigForm(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
      },
    );
  }

  Widget _buildConfigForm() {
    final tp = ThemeProvider.of(context);
    final theme = tp.currentTheme;
    final isDark = theme.brightness == Brightness.dark;

    final fields = [
      _ConfigField(controller: _webdavUrl, label: '服务器 URL', hint: 'http://dav.example.com', icon: Icons.link_rounded),
      _ConfigField(controller: _webdavUser, label: '用户名', hint: 'user', icon: Icons.person_rounded),
      _ConfigField(controller: _webdavPass, label: '密码', hint: '••••••', icon: Icons.lock_rounded, obscure: true),
    ];

    return SingleChildScrollView(
      key: const ValueKey('config_form'),
      padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(context).padding.bottom + 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...fields.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: f,
              )),
          // Remember password & clear saved
          ...[
            const SizedBox(height: 4),
            Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _rememberPassword,
                    onChanged: (v) => setState(() => _rememberPassword = v ?? true),
                    activeColor: _typeColor,
                    checkColor: Colors.white,
                    side: BorderSide(color: theme.textSecondary.withValues(alpha: 0.3)),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '记住连接信息',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: theme.textSecondary.withValues(alpha: 0.7),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _clearSavedWebdavInfo,
                  child: Text(
                    '清除保存',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.redAccent.withValues(alpha: 0.7),
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.redAccent.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          _ConnectButton(
            connecting: _connecting,
            typeColor: _typeColor,
            onTap: _connect,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.primaryColor.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: theme.textSecondary.withValues(alpha: 0.4), size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '输入 WebDAV 服务器地址即可连接并浏览远程文件。',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: theme.textSecondary.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileList() {
    final tp = ThemeProvider.of(context);
    final theme = tp.currentTheme;

    return FadeTransition(
      key: const ValueKey('file_list'),
      opacity: _fileListAnim,
      child: Column(
        children: [
          // Path indicator + back button
          if (_currentPath != '/')
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: GlassCard(
                onTap: _goUpDir,
                borderRadius: 10,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.arrow_upward_rounded, size: 16, color: _typeColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _currentPath,
                        style: GoogleFonts.inter(fontSize: 12, color: theme.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(context).padding.bottom + 20),
              itemCount: _files.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Icon(Icons.folder_rounded, color: _typeColor, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          '远程文件',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: theme.textSecondary.withValues(alpha: 0.5),
                            letterSpacing: 1.2,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_files.length} 项',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: theme.textSecondary.withValues(alpha: 0.3),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final file = _files[index - 1];
                return _AnimatedListItem(
                  index: index - 1,
                  baseDelay: const Duration(milliseconds: 80),
                  staggerDelay: const Duration(milliseconds: 50),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _WebDavFileCard(
                      file: file,
                      typeColor: _typeColor,
                      theme: theme,
                      onTap: () => file.isDirectory ? _navigateDir(file.name) : _downloadAndOpen(file),
                    ),
                  ),
                );
            },
          ),
        ),
      ],
    ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// WEBDAV FILE CARD - 带按下反馈
// ═══════════════════════════════════════════════════════════════════════

class _WebDavFileCard extends StatefulWidget {
  final _RemoteFile file;
  final Color typeColor;
  final AppTheme theme;
  final VoidCallback onTap;

  const _WebDavFileCard({
    required this.file,
    required this.typeColor,
    required this.theme,
    required this.onTap,
  });

  @override
  State<_WebDavFileCard> createState() => _WebDavFileCardState();
}

class _WebDavFileCardState extends State<_WebDavFileCard> with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.96,
      upperBound: 1.0,
    );
    _scaleAnim = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    );
    _scaleController.value = 1.0;
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _scaleController.animateTo(0.96, duration: const Duration(milliseconds: 100), curve: Curves.easeOutCubic);
  }

  void _onTapUp(TapUpDetails details) {
    _scaleController.animateTo(1.0, duration: const Duration(milliseconds: 150), curve: Curves.easeOutCubic);
    widget.onTap();
  }

  void _onTapCancel() {
    _scaleController.animateTo(1.0, duration: const Duration(milliseconds: 150), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnim,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: GlassCard(
          borderRadius: 14,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.file.isDirectory
                        ? [widget.typeColor.withValues(alpha: 0.35), widget.typeColor.withValues(alpha: 0.1)]
                        : [widget.theme.primaryColor.withValues(alpha: 0.3), widget.theme.primaryColor.withValues(alpha: 0.1)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  widget.file.isDirectory ? Icons.folder_rounded : Icons.description_rounded,
                  color: Colors.white70,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.file.name,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: widget.theme.textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: widget.theme.textSecondary.withValues(alpha: 0.3), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfigField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;

  const _ConfigField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final tp = ThemeProvider.of(context);
    final theme = tp.currentTheme;
    final isDark = theme.brightness == Brightness.dark;

    return GlassCard(
      borderRadius: 14,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          Icon(icon, color: theme.textSecondary.withValues(alpha: 0.4), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              keyboardType: keyboardType,
              style: GoogleFonts.inter(fontSize: 14, color: theme.textColor),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: GoogleFonts.inter(
                  fontSize: 12,
                  color: theme.textSecondary.withValues(alpha: 0.5),
                ),
                hintText: hint,
                hintStyle: GoogleFonts.inter(
                  fontSize: 13,
                  color: theme.textSecondary.withValues(alpha: 0.3),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              cursorColor: theme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _RemoteFile {
  final String name;
  final bool isDirectory;
  _RemoteFile(this.name, this.isDirectory);
}

// ═══════════════════════════════════════════════════════════════════════
// CONNECT BUTTON - 带按下反馈
// ═══════════════════════════════════════════════════════════════════════

class _ConnectButton extends StatefulWidget {
  final bool connecting;
  final Color typeColor;
  final VoidCallback onTap;

  const _ConnectButton({
    required this.connecting,
    required this.typeColor,
    required this.onTap,
  });

  @override
  State<_ConnectButton> createState() => _ConnectButtonState();
}

class _ConnectButtonState extends State<_ConnectButton> with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.96,
      upperBound: 1.0,
    );
    _scaleAnim = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    );
    _scaleController.value = 1.0;
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (!widget.connecting) {
      _scaleController.animateTo(0.96, duration: const Duration(milliseconds: 100), curve: Curves.easeOutCubic);
    }
  }

  void _onTapUp(TapUpDetails details) {
    _scaleController.animateTo(1.0, duration: const Duration(milliseconds: 150), curve: Curves.easeOutCubic);
  }

  void _onTapCancel() {
    _scaleController.animateTo(1.0, duration: const Duration(milliseconds: 150), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      child: ShimmerSweep(
        key: ValueKey(widget.connecting),
        child: ScaleTransition(
          scale: _scaleAnim,
          child: GestureDetector(
            onTapDown: _onTapDown,
            onTapUp: _onTapUp,
            onTapCancel: _onTapCancel,
            onTap: widget.connecting ? null : widget.onTap,
            child: GlassCard(
              borderRadius: 16,
              padding: EdgeInsets.zero,
              color: widget.connecting
                  ? widget.typeColor.withValues(alpha: 0.15)
                  : widget.typeColor.withValues(alpha: 0.2),
              border: Border.all(
                color: widget.connecting
                    ? widget.typeColor.withValues(alpha: 0.25)
                    : widget.typeColor.withValues(alpha: 0.35),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                alignment: Alignment.center,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: widget.connecting
                      ? SizedBox(
                          key: const ValueKey('loading'),
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: widget.typeColor,
                            value: null,
                          ),
                        )
                      : Row(
                          key: const ValueKey('connect'),
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.link_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              '连接',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

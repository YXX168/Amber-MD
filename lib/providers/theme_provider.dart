import 'package:flutter/material.dart';

import '../models/app_theme.dart';
import '../models/font_config.dart';
import '../services/preferences_service.dart';

/// 全局主题变更版本号 — 每次主题/字体/行高变更时递增
/// 所有页面通过 ValueListenableBuilder 监听此值以即时重建
final ValueNotifier<int> globalThemeVersion = ValueNotifier<int>(0);

/// 全局主题过渡通知器 — 触发交叉淡入淡出动画
final ValueNotifier<double> globalThemeTransition =
    ValueNotifier<double>(1.0);

/// 主题 Provider — InheritedWidget 实现，管理全局主题状态和持久化
class ThemeProvider extends StatefulWidget {
  final Widget child;

  const ThemeProvider({super.key, required this.child});

  /// 获取最近的 ThemeProvider 数据
  static ThemeProviderData of(BuildContext context) {
    final inherited =
        context.dependOnInheritedWidgetOfExactType<_ThemeProviderInherited>();
    if (inherited == null) {
      throw FlutterError(
        'ThemeProvider not found in widget tree. '
        'Make sure your widget is wrapped in ThemeProvider.',
      );
    }
    return inherited.data;
  }

  @override
  State<ThemeProvider> createState() => _ThemeProviderState();
}

class _ThemeProviderState extends State<ThemeProvider> {
  late ThemeProviderData _data;

  @override
  void initState() {
    super.initState();
    _data = ThemeProviderData(
      mode: AppThemeMode.midnight,
      fontSizeOption: FontSizeOption.medium,
      lineHeight: 1.75,
      letterSpacing: 0.0,
    );
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final themeId = PreferencesService.themeMode;
    final fontIdx = PreferencesService.fontSizeIndex;
    final lh = PreferencesService.lineHeight;
    final ls = PreferencesService.letterSpacing;

    final mode = AppThemeMode.values.firstWhere(
      (m) => appThemes[m]!.id == themeId,
      orElse: () => AppThemeMode.midnight,
    );
    final fontSize = FontSizeOption
        .values[fontIdx.clamp(0, FontSizeOption.values.length - 1)];

    if (mounted) {
      setState(() {
        _data = ThemeProviderData(
          mode: mode,
          fontSizeOption: fontSize,
          lineHeight: lh,
          letterSpacing: ls,
        );
      });
    }
    globalThemeVersion.value++;
  }

  Future<void> _setTheme(AppThemeMode mode) async {
    await PreferencesService.setThemeMode(appThemes[mode]!.id);
    globalThemeTransition.value = 0.0;
    Future.delayed(const Duration(milliseconds: 50), () {
      globalThemeTransition.value = 1.0;
    });
    if (mounted) {
      setState(() {
        _data = ThemeProviderData(
          mode: mode,
          fontSizeOption: _data.fontSizeOption,
          lineHeight: _data.lineHeight,
          letterSpacing: _data.letterSpacing,
        );
      });
    }
    globalThemeVersion.value++;
  }

  Future<void> _setFontSize(FontSizeOption opt) async {
    await PreferencesService.setFontSizeIndex(opt.index);
    if (mounted) {
      setState(() {
        _data = ThemeProviderData(
          mode: _data.mode,
          fontSizeOption: opt,
          lineHeight: _data.lineHeight,
          letterSpacing: _data.letterSpacing,
        );
      });
    }
    globalThemeVersion.value++;
  }

  Future<void> _setLineHeight(double h) async {
    await PreferencesService.setLineHeight(h);
    if (mounted) {
      setState(() {
        _data = ThemeProviderData(
          mode: _data.mode,
          fontSizeOption: _data.fontSizeOption,
          lineHeight: h,
          letterSpacing: _data.letterSpacing,
        );
      });
    }
    globalThemeVersion.value++;
  }

  Future<void> _setLetterSpacing(double sp) async {
    await PreferencesService.setLetterSpacing(sp);
    if (mounted) {
      setState(() {
        _data = ThemeProviderData(
          mode: _data.mode,
          fontSizeOption: _data.fontSizeOption,
          lineHeight: _data.lineHeight,
          letterSpacing: sp,
        );
      });
    }
    globalThemeVersion.value++;
  }

  @override
  Widget build(BuildContext context) {
    return _ThemeProviderInherited(
      data: _data.copyWith(
        setTheme: _setTheme,
        setFontSize: _setFontSize,
        setLineHeight: _setLineHeight,
        setLetterSpacing: _setLetterSpacing,
      ),
      child: widget.child,
    );
  }
}

class _ThemeProviderInherited extends InheritedWidget {
  final ThemeProviderData data;

  const _ThemeProviderInherited({
    required this.data,
    required super.child,
  });

  @override
  bool updateShouldNotify(_ThemeProviderInherited old) {
    return data != old.data;
  }
}

/// 主题 Provider 数据类
class ThemeProviderData {
  final AppThemeMode mode;
  final FontSizeOption fontSizeOption;
  final double lineHeight;
  final double letterSpacing;

  // 方法引用（由 State 注入）
  final Future<void> Function(AppThemeMode mode)? setTheme;
  final Future<void> Function(FontSizeOption opt)? setFontSize;
  final Future<void> Function(double h)? setLineHeight;
  final Future<void> Function(double sp)? setLetterSpacing;

  const ThemeProviderData({
    required this.mode,
    required this.fontSizeOption,
    required this.lineHeight,
    required this.letterSpacing,
    this.setTheme,
    this.setFontSize,
    this.setLineHeight,
    this.setLetterSpacing,
  });

  /// 获取当前 AppTheme 对象
  AppTheme get currentTheme => appThemes[mode]!;

  /// 获取字体大小数值
  double get fontSize => fontSizeMap[fontSizeOption]!;

  ThemeProviderData copyWith({
    AppThemeMode? mode,
    FontSizeOption? fontSizeOption,
    double? lineHeight,
    double? letterSpacing,
    Future<void> Function(AppThemeMode mode)? setTheme,
    Future<void> Function(FontSizeOption opt)? setFontSize,
    Future<void> Function(double h)? setLineHeight,
    Future<void> Function(double sp)? setLetterSpacing,
  }) {
    return ThemeProviderData(
      mode: mode ?? this.mode,
      fontSizeOption: fontSizeOption ?? this.fontSizeOption,
      lineHeight: lineHeight ?? this.lineHeight,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      setTheme: setTheme ?? this.setTheme,
      setFontSize: setFontSize ?? this.setFontSize,
      setLineHeight: setLineHeight ?? this.setLineHeight,
      setLetterSpacing: setLetterSpacing ?? this.setLetterSpacing,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ThemeProviderData &&
        other.mode == mode &&
        other.fontSizeOption == fontSizeOption &&
        other.lineHeight == lineHeight &&
        other.letterSpacing == letterSpacing;
  }

  @override
  int get hashCode =>
      mode.hashCode ^
      fontSizeOption.hashCode ^
      lineHeight.hashCode ^
      letterSpacing.hashCode;
}

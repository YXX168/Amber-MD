import 'package:flutter/material.dart';

/// 应用主题模式枚举
enum AppThemeMode { midnight, aurora, forest, ocean, sakura }

/// 应用主题数据类
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

/// 所有主题定义
const Map<AppThemeMode, AppTheme> appThemes = {
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

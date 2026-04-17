import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/app_theme.dart';
import '../models/font_config.dart';
import '../providers/theme_provider.dart';
import '../widgets/animated_gradient_bg.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_icon_button.dart';
import '../widgets/scale_on_tap.dart';
import '../widgets/section_title.dart';

/// 设置页面 — 主题选择、字体大小、行高、字间距
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
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
                    // 顶部栏
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      child: GlassCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            GlassIconButton(
                              icon: Icons.arrow_back_rounded,
                              onTap: () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.settings_rounded,
                                color: theme.primaryColor, size: 22),
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
                    // 设置内容
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          8,
                          20,
                          MediaQuery.of(context).padding.bottom + 40,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 主题风格选择
                            const SectionTitle('主题风格'),
                            const SizedBox(height: 12),
                            _buildThemeSelector(tp, theme, isDark),
                            const SizedBox(height: 28),

                            // 字体大小选择
                            const SectionTitle('字体大小'),
                            const SizedBox(height: 12),
                            _buildFontSizeSelector(tp, theme, isDark),
                            const SizedBox(height: 28),

                            // 字间距选择
                            const SectionTitle('字间距'),
                            const SizedBox(height: 12),
                            _buildLetterSpacingSelector(tp, theme, isDark),
                            const SizedBox(height: 28),

                            // 行高选择
                            const SectionTitle('行高'),
                            const SizedBox(height: 12),
                            _buildLineHeightSelector(tp, theme, isDark),
                            const SizedBox(height: 28),

                            // 预览
                            const SectionTitle('预览'),
                            const SizedBox(height: 12),
                            _buildPreview(tp, theme),
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

  Widget _buildThemeSelector(
      ThemeProviderData tp, AppTheme theme, bool isDark) {
    return Row(
      children: AppThemeMode.values.map((mode) {
        final t = appThemes[mode]!;
        final selected = tp.mode == mode;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ScaleOnTap(
              onTap: () => tp.setTheme?.call(mode),
              child: GlassCard(
                borderRadius: 14,
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
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
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 18)
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t.name,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: theme.textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFontSizeSelector(
      ThemeProviderData tp, AppTheme theme, bool isDark) {
    return Row(
      children: FontSizeOption.values.map((opt) {
        final selected = tp.fontSizeOption == opt;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ScaleOnTap(
              onTap: () => tp.setFontSize?.call(opt),
              child: GlassCard(
                borderRadius: 12,
                padding: const EdgeInsets.symmetric(vertical: 14),
                color: selected
                    ? theme.primaryColor.withValues(alpha: 0.15)
                    : null,
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
                    fontSizeLabels[opt]!,
                    style: GoogleFonts.inter(
                      fontSize: fontSizeMap[opt]! - 2,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color:
                          selected ? theme.primaryColor : theme.textColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLetterSpacingSelector(
      ThemeProviderData tp, AppTheme theme, bool isDark) {
    return Row(
      children: letterSpacingOptions.map((sp) {
        final selected = (tp.letterSpacing - sp).abs() < 0.01;
        final label = sp == 0.0 ? '默认' : '${sp.toStringAsFixed(1)}';
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ScaleOnTap(
              onTap: () => tp.setLetterSpacing?.call(sp),
              child: GlassCard(
                borderRadius: 12,
                padding: const EdgeInsets.symmetric(vertical: 14),
                color: selected
                    ? theme.primaryColor.withValues(alpha: 0.15)
                    : null,
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
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color:
                          selected ? theme.primaryColor : theme.textColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLineHeightSelector(
      ThemeProviderData tp, AppTheme theme, bool isDark) {
    return Row(
      children: lineHeightOptions.map((h) {
        final selected = tp.lineHeight == h;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ScaleOnTap(
              onTap: () => tp.setLineHeight?.call(h),
              child: GlassCard(
                borderRadius: 12,
                padding: const EdgeInsets.symmetric(vertical: 14),
                color: selected
                    ? theme.primaryColor.withValues(alpha: 0.15)
                    : null,
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
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color:
                          selected ? theme.primaryColor : theme.textColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPreview(ThemeProviderData tp, AppTheme theme) {
    return GlassCard(
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
    );
  }
}

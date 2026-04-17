import 'dart:ui';

import 'package:flutter/material.dart';

import '../providers/theme_provider.dart';

/// 毛玻璃效果应用栏
class GlassAppBar extends StatelessWidget {
  final Widget child;

  const GlassAppBar({super.key, required this.child});

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

import 'dart:ui';

import 'package:flutter/material.dart';

import '../providers/theme_provider.dart';

/// 毛玻璃浮动按钮 — 用于返回顶部等场景
class GlassFAB extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final double borderRadius;

  const GlassFAB({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius = 24,
  });

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

import 'dart:math';

import 'package:flutter/material.dart';

import '../models/app_theme.dart';
import '../providers/theme_provider.dart';

/// 动画渐变背景 — 支持 Aurora 主题特殊正弦动画
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
      duration: const Duration(seconds: 12),
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
                        Color.lerp(colors[0], colors[1],
                            0.5 + 0.5 * sin(_ctrl.value * 2 * pi))!,
                        Color.lerp(colors[1], colors[2],
                            0.5 + 0.5 * cos(_ctrl.value * 2 * pi))!,
                        Color.lerp(
                            colors[2],
                            colors.length > 3 ? colors[3] : colors[0],
                            0.5 +
                                0.5 *
                                    sin(_ctrl.value * 2 * pi + 1.0))!,
                        Color.lerp(colors[0], colors[1],
                            0.3 + 0.3 * cos(_ctrl.value * 2 * pi + 2.0))!,
                      ]
                    : [
                        Color.lerp(colors[0], colors[1], _ctrl.value * 0.3)!,
                        colors.length > 2
                            ? Color.lerp(colors[1], colors[2],
                                _ctrl.value * 0.2)!
                            : colors[1],
                        Color.lerp(
                            colors[0],
                            colors.length > 2 ? colors[2] : colors[1],
                            1 - _ctrl.value * 0.3)!,
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

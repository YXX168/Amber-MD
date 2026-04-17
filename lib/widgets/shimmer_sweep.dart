import 'package:flutter/material.dart';

import '../providers/theme_provider.dart';

/// 闪光扫光动画 — 4 秒周期的 ShaderMask 光效
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
      duration: const Duration(seconds: 4),
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

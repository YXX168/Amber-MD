import 'package:flutter/material.dart';

import '../providers/theme_provider.dart';

/// 毛玻璃卡片组件 — 支持进入动画和可选的 BackdropFilter 模糊
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

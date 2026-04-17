import 'package:flutter/material.dart';

import '../providers/theme_provider.dart';

/// 毛玻璃图标按钮 — 带按下缩放反馈
class GlassIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool compact;

  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.compact = false,
  });

  @override
  State<GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<GlassIconButton>
    with SingleTickerProviderStateMixin {
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
    _scaleController.animateTo(0.88,
        duration: const Duration(milliseconds: 80),
        curve: Curves.easeOutCubic);
  }

  void _onTapUp(TapUpDetails details) {
    _scaleController.animateTo(1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.elasticOut);
    widget.onTap();
  }

  void _onTapCancel() {
    _scaleController.animateTo(1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic);
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

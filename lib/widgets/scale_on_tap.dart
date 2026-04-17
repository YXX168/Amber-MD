import 'package:flutter/material.dart';

/// 通用按下缩放反馈组件
class ScaleOnTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleAmount;

  const ScaleOnTap({
    super.key,
    required this.child,
    this.onTap,
    this.scaleAmount = 0.96,
  });

  @override
  State<ScaleOnTap> createState() => _ScaleOnTapState();
}

class _ScaleOnTapState extends State<ScaleOnTap>
    with SingleTickerProviderStateMixin {
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
    _controller.animateTo(widget.scaleAmount,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic);
  }

  void _onTapUp(TapUpDetails details) {
    _controller.animateTo(1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic);
  }

  void _onTapCancel() {
    _controller.animateTo(1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic);
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

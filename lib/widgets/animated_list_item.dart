import 'dart:async';

import 'package:flutter/material.dart';

/// 交错延迟进场动画 — 列表项的渐入+滑入效果
class AnimatedListItem extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration baseDelay;
  final Duration staggerDelay;

  const AnimatedListItem({
    super.key,
    required this.child,
    required this.index,
    this.baseDelay = const Duration(milliseconds: 100),
    this.staggerDelay = const Duration(milliseconds: 60),
  });

  @override
  State<AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<AnimatedListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnim;
  late Animation<Offset> _slideAnim;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _opacityAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    final delay = widget.baseDelay + (widget.staggerDelay * widget.index);
    _delayTimer = Timer(delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: widget.child,
      ),
    );
  }
}

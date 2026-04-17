import 'package:flutter/material.dart';

import '../providers/theme_provider.dart';

/// 空状态动画组件 — 脉冲动画图标 + 提示文字
class EmptyState extends StatefulWidget {
  final VoidCallback? onPick;

  const EmptyState({super.key, this.onPick});

  @override
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
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

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + _ctrl.value * 0.15,
                child: Transform.rotate(
                  angle: _ctrl.value * 0.08,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.primaryColor
                              .withValues(alpha: 0.3 + _ctrl.value * 0.15),
                          theme.accentColor
                              .withValues(alpha: 0.1 + _ctrl.value * 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: theme.primaryColor
                            .withValues(alpha: 0.15 + _ctrl.value * 0.25),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.primaryColor
                              .withValues(alpha: 0.15 + _ctrl.value * 0.3),
                          blurRadius: 30 + _ctrl.value * 25,
                          spreadRadius: 3 + _ctrl.value * 8,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.description_rounded,
                      size: 44,
                      color: theme.textSecondary
                          .withValues(alpha: 0.6 + _ctrl.value * 0.35),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            '暂无文档',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: theme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '打开一个文件开始阅读',
            style: TextStyle(
              fontSize: 13,
              color: theme.textSecondary.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

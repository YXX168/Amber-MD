import 'package:flutter/material.dart';

import '../providers/theme_provider.dart';

/// 空状态动画组件 — 柔和呼吸光效 + 提示文字
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
      duration: const Duration(milliseconds: 3000),
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
              // 柔和呼吸光效：光晕扩散 + 图标透明度微变，不倾斜不缩放
              final glowAlpha = 0.12 + _ctrl.value * 0.18;
              final iconAlpha = 0.45 + _ctrl.value * 0.2;
              return Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.primaryColor.withValues(alpha: glowAlpha),
                      theme.accentColor.withValues(alpha: glowAlpha * 0.5),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: theme.primaryColor
                        .withValues(alpha: 0.08 + _ctrl.value * 0.12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.primaryColor
                          .withValues(alpha: glowAlpha * 0.6),
                      blurRadius: 28 + _ctrl.value * 20,
                      spreadRadius: 2 + _ctrl.value * 6,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.description_rounded,
                  size: 42,
                  color: theme.textSecondary.withValues(alpha: iconAlpha),
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

import 'package:flutter/material.dart';

import '../providers/theme_provider.dart';

/// 设置页面区块标题
class SectionTitle extends StatelessWidget {
  final String title;

  const SectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final tp = ThemeProvider.of(context);
    final theme = tp.currentTheme;

    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: theme.textSecondary.withValues(alpha: 0.6),
        letterSpacing: 1.2,
      ),
    );
  }
}

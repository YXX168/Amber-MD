import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';

import '../models/app_theme.dart';
import '../models/font_config.dart';
import '../providers/theme_provider.dart';
import '../services/preferences_service.dart';
import '../widgets/animated_gradient_bg.dart';
import '../widgets/animated_list_item.dart';
import '../widgets/empty_state.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_fab.dart';
import '../widgets/glass_icon_button.dart';
import '../widgets/scale_on_tap.dart';

/// 全局回调：处理运行时收到的 Intent
typedef IntentFileCallback = void Function(String filePath);
IntentFileCallback? globalIntentFileCallback;

/// 初始文件路径（冷启动时由 Intent 设置）
String? initialFilePath;

/// 辅助函数：获取文件类型
String getFileType(String path) {
  final ext = p.extension(path).toLowerCase().replaceAll('.', '');
  if (ext == 'md' || ext == 'markdown') return 'md';
  if (ext == 'txt' || ext == 'text') return 'txt';
  if (ext == 'html' || ext == 'htm') return 'html';
  if (ext == 'json') return 'json';
  return 'plain';
}

/// 辅助函数：获取文件类型标签
String getFileTypeLabel(String path) {
  final ext = p.extension(path).toLowerCase().replaceAll('.', '');
  const labels = {
    'md': 'MD',
    'markdown': 'MD',
    'txt': 'TXT',
    'text': 'TXT',
    'html': 'HTML',
    'htm': 'HTML',
    'json': 'JSON',
    'xml': 'XML',
    'yaml': 'YAML',
    'yml': 'YAML',
    'csv': 'CSV',
    'log': 'LOG',
    'cfg': 'CFG',
    'ini': 'INI',
    'conf': 'CONF',
  };
  return labels[ext] ?? ext.toUpperCase();
}

/// 首页 — 最近文件列表 + 文件选择器 + FAB
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<String> _recentFiles = [];

  @override
  void initState() {
    super.initState();
    _loadRecent();

    // 注册全局 Intent 回调
    globalIntentFileCallback = (filePath) {
      debugPrint('[HomePage] 全局回调收到文件: $filePath');
      if (mounted) {
        _addToRecent(filePath);
        Navigator.pushNamed(context, '/reader', arguments: {
          'path': filePath,
          'fileType': getFileType(filePath),
        });
      }
    };

    // 处理初始 intent 文件
    if (initialFilePath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final fp = initialFilePath!;
        initialFilePath = null;
        _addToRecent(fp);
        Navigator.pushNamed(context, '/reader', arguments: {
          'path': fp,
          'fileType': getFileType(fp),
        });
      });
    }
  }

  @override
  void dispose() {
    globalIntentFileCallback = null;
    super.dispose();
  }

  Future<void> _loadRecent() async {
    if (!mounted) return;
    setState(() {
      _recentFiles = PreferencesService.recentFiles;
    });
  }

  Future<void> _addToRecent(String path) async {
    _recentFiles.remove(path);
    _recentFiles.insert(0, path);
    if (_recentFiles.length > 20) {
      _recentFiles = _recentFiles.sublist(0, 20);
    }
    await PreferencesService.setRecentFiles(_recentFiles);
    if (mounted) setState(() {});
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'md', 'markdown', 'txt', 'html', 'htm',
          'json', 'xml', 'yaml', 'yml', 'csv',
          'log', 'cfg', 'ini', 'conf', 'text',
        ],
      );
      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        await _addToRecent(filePath);
        if (mounted) {
          Navigator.pushNamed(context, '/reader', arguments: {
            'path': filePath,
            'fileType': getFileType(filePath),
          });
        }
      }
    } catch (e) {
      debugPrint('[HomePage] 文件选择失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('无法选择文件: $e',
                style: GoogleFonts.inter(color: Colors.white)),
            backgroundColor: Colors.redAccent.withValues(alpha: 0.8),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _removeRecent(String path) async {
    HapticFeedback.mediumImpact();
    _recentFiles.remove(path);
    await PreferencesService.setRecentFiles(_recentFiles);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: globalThemeVersion,
      builder: (context, _, __) {
        final tp = ThemeProvider.of(context);
        final theme = tp.currentTheme;
        final isDark = theme.brightness == Brightness.dark;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: isDark
              ? const SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.light,
                  systemNavigationBarColor: Colors.transparent,
                  systemNavigationBarIconBrightness: Brightness.light,
                )
              : const SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.dark,
                  systemNavigationBarColor: Colors.transparent,
                  systemNavigationBarIconBrightness: Brightness.dark,
                ),
          child: Scaffold(
            extendBody: true,
            extendBodyBehindAppBar: true,
            body: AnimatedGradientBg(
              child: SafeArea(
                top: true,
                bottom: false,
                child: Column(
                  children: [
                    // 顶部栏
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: GlassCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    theme.primaryColor,
                                    theme.accentColor
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.auto_stories_rounded,
                                  color: Colors.white, size: 15),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Amber',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: theme.textColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            GlassIconButton(
                              icon: Icons.folder_open_rounded,
                              onTap: _pickFile,
                              compact: true,
                            ),
                            const SizedBox(width: 2),
                            GlassIconButton(
                              icon: Icons.cloud_outlined,
                              onTap: () => Navigator.pushNamed(
                                  context, '/network_storage',
                                  arguments: {'type': 'webdav'}),
                              compact: true,
                            ),
                            const SizedBox(width: 2),
                            GlassIconButton(
                              icon: Icons.settings_rounded,
                              onTap: () =>
                                  Navigator.pushNamed(context, '/settings'),
                              compact: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 最近文件列表
                    Expanded(
                      child: _recentFiles.isEmpty
                          ? const EmptyState()
                          : ListView.builder(
                              padding: EdgeInsets.fromLTRB(
                                20,
                                0,
                                20,
                                MediaQuery.of(context).padding.bottom + 100,
                              ),
                              itemCount: _recentFiles.length + 1,
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Text(
                                      '最近文档',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: theme.textSecondary
                                            .withValues(alpha: 0.5),
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  );
                                }
                                final filePath = _recentFiles[index - 1];
                                return AnimatedListItem(
                                  index: index - 1,
                                  child: _FileCard(
                                    filePath: filePath,
                                    onTap: () {
                                      _addToRecent(filePath);
                                      Navigator.pushNamed(context, '/reader',
                                          arguments: {
                                            'path': filePath,
                                            'fileType': getFileType(filePath),
                                          });
                                    },
                                    onDismiss: () => _removeRecent(filePath),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
            floatingActionButton: _buildFab(),
            floatingActionButtonLocation:
                FloatingActionButtonLocation.centerFloat,
          ),
        );
      },
    );
  }

  Widget _buildFab() {
    return ScaleOnTap(
      scaleAmount: 0.94,
      onTap: _pickFile,
      child: GlassCard(
        borderRadius: 28,
        padding: EdgeInsets.zero,
        color: ThemeProvider.of(context).currentTheme.fabColor,
        border: Border.all(
            color: ThemeProvider.of(context).currentTheme.fabBorderColor,
            width: 1),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded,
                  color: ThemeProvider.of(context).currentTheme.textColor,
                  size: 24),
              const SizedBox(width: 10),
              Text(
                '打开文档',
                style: GoogleFonts.inter(
                  color: ThemeProvider.of(context).currentTheme.textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 文件卡片组件 — 带文件类型标签、可滑动删除
class _FileCard extends StatefulWidget {
  final String filePath;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _FileCard({
    required this.filePath,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_FileCard> createState() => _FileCardState();
}

class _FileCardState extends State<_FileCard> with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnim;
  bool? _fileExists;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.96,
      upperBound: 1.0,
    );
    _scaleAnim = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    );
    _scaleController.value = 1.0;
    Future.microtask(() async {
      _fileExists = await File(widget.filePath).exists();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _scaleController.animateTo(0.96,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic);
  }

  void _onTapUp(TapUpDetails details) {
    _scaleController.animateTo(1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic);
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

    final name = p.basename(widget.filePath);
    final fileTypeLabel = getFileTypeLabel(widget.filePath);
    final exists = _fileExists ?? true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: Key(widget.filePath),
        direction: DismissDirection.endToStart,
        onDismissed: (_) {
          HapticFeedback.mediumImpact();
          widget.onDismiss();
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Colors.redAccent.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete_outline, color: Colors.white70),
        ),
        child: ScaleTransition(
          scale: _scaleAnim,
          child: GestureDetector(
            onTapDown: _onTapDown,
            onTapUp: _onTapUp,
            onTapCancel: _onTapCancel,
            onTap: widget.onTap,
            child: GlassCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: exists
                            ? [
                                theme.primaryColor
                                    .withValues(alpha: 0.4),
                                theme.accentColor.withValues(alpha: 0.2)
                              ]
                            : [
                                Colors.redAccent.withValues(alpha: 0.3),
                                Colors.red.withValues(alpha: 0.1)
                              ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      exists
                          ? Icons.description_rounded
                          : Icons.error_outline_rounded,
                      color: Colors.white70,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: exists
                                ? theme.textColor
                                : theme.textSecondary
                                    .withValues(alpha: 0.4),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.primaryColor
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                fileTypeLabel,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: theme.primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                p.dirname(widget.filePath),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: theme.textSecondary
                                      .withValues(alpha: 0.3),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded,
                      color: theme.textSecondary.withValues(alpha: 0.3),
                      size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

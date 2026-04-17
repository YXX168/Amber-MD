import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;

import '../models/app_theme.dart';
import '../pages/home_page.dart';
import '../providers/theme_provider.dart';
import '../widgets/animated_gradient_bg.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_fab.dart';
import '../widgets/glass_icon_button.dart';
import '../widgets/scale_on_tap.dart';
// shimmer_sweep removed — causes unnecessary repaint during loading

/// 阅读器页面 — 支持 Markdown 渲染、编辑模式、搜索、自动隐藏 AppBar
class ReaderPage extends StatefulWidget {
  final String filePath;
  final String fileType;

  const ReaderPage({super.key, required this.filePath, this.fileType = 'md'});

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> with TickerProviderStateMixin {
  String _content = '';
  String _title = '';
  bool _loading = true;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  final ScrollController _scrollCtrl = ScrollController();
  bool _showBackToTop = false;
  Timer? _backToTopHideTimer;
  bool _showAppBar = true;
  double _lastScrollOffset = 0;
  double _scrollDeltaAccum = 0;
  Timer? _searchDebounceTimer;

  // 编辑模式
  bool _isEditing = false;
  late TextEditingController _editController;

  // 搜索模式
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<int> _matchIndices = [];
  int _currentMatchIndex = -1;

  String get _fileType => widget.fileType;
  bool get _isMarkdown => _fileType == 'md';

  @override
  void initState() {
    super.initState();
    _title = p.basename(widget.filePath);
    _editController = TextEditingController();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _loadFile();

    _scrollCtrl.addListener(_onScroll);

    _searchController.addListener(() {
      _searchDebounceTimer?.cancel();
      _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
        _performSearch(_searchController.text);
      });
    });
  }

  void _onScroll() {
    final offset = _scrollCtrl.offset;
    final showFab = offset > 300;
    final delta = offset - _lastScrollOffset;
    bool needsUpdate = false;
    bool newShowAppBar = _showAppBar;

    if (showFab != _showBackToTop) {
      _showBackToTop = showFab;
      needsUpdate = true;
    }

    _backToTopHideTimer?.cancel();
    if (showFab) {
      _backToTopHideTimer = Timer(const Duration(seconds: 1), () {
        if (mounted && _showBackToTop) setState(() => _showBackToTop = false);
      });
    }

    if (delta > 0) {
      _scrollDeltaAccum = 0;
      if (offset > 60 && _showAppBar) {
        newShowAppBar = false;
        needsUpdate = true;
      }
    } else if (delta < 0) {
      _scrollDeltaAccum += delta.abs();
      if (offset < 200 || _scrollDeltaAccum > 100) {
        if (!_showAppBar) {
          newShowAppBar = true;
          needsUpdate = true;
        }
        _scrollDeltaAccum = 0;
      }
    }

    if (needsUpdate) {
      setState(() => _showAppBar = newShowAppBar);
    }
    _lastScrollOffset = offset;
  }

  @override
  void dispose() {
    _backToTopHideTimer?.cancel();
    _searchDebounceTimer?.cancel();
    _scrollCtrl.dispose();
    _editController.dispose();
    _searchController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadFile() async {
    try {
      final file = File(widget.filePath);
      var content = await file.readAsString();

      // JSON 自动格式化
      if (_fileType == 'json') {
        try {
          final decoded = jsonDecode(content);
          const encoder = JsonEncoder.withIndent('  ');
          content = encoder.convert(decoded);
        } catch (_) {}
      }

      if (mounted) {
        // 先启动淡入动画，同时设置内容
        _fadeController.forward(from: 0);
        setState(() {
          _content = content;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _fadeController.forward(from: 0);
        setState(() {
          _content = '# 读取失败\n\n无法读取文件:\n```\n$e\n```';
          _loading = false;
        });
      }
    }
  }

  void _enterEditMode() {
    _editController.text = _content;
    setState(() => _isEditing = true);
  }

  void _exitEditMode() {
    setState(() => _isEditing = false);
  }

  Future<void> _saveFile() async {
    try {
      final file = File(widget.filePath);
      await file.writeAsString(_editController.text);
      if (mounted) {
        final tp = ThemeProvider.of(context);
        final theme = tp.currentTheme;
        setState(() {
          _content = _editController.text;
          _isEditing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('文件已保存',
                style: GoogleFonts.inter(color: Colors.white)),
            backgroundColor: theme.primaryColor.withValues(alpha: 0.8),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e',
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

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchQuery = '';
        _matchIndices = [];
        _currentMatchIndex = -1;
        _searchController.clear();
      }
    });
  }

  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchQuery = '';
        _matchIndices = [];
        _currentMatchIndex = -1;
      });
      return;
    }
    final lowerContent = _content.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final indices = <int>[];
    int start = 0;
    while (true) {
      final idx = lowerContent.indexOf(lowerQuery, start);
      if (idx == -1) break;
      indices.add(idx);
      start = idx + 1;
    }
    setState(() {
      _searchQuery = query;
      _matchIndices = indices;
      _currentMatchIndex = indices.isNotEmpty ? 0 : -1;
    });
    if (indices.isNotEmpty) {
      _scrollToMatch(0);
    }
  }

  void _scrollToMatch(int matchListIndex) {
    if (_matchIndices.isEmpty ||
        matchListIndex < 0 ||
        matchListIndex >= _matchIndices.length) return;
    final charIndex = _matchIndices[matchListIndex];
    final totalChars = _content.length;
    if (totalChars == 0) return;

    final ratio = charIndex / totalChars;
    final maxScroll = _scrollCtrl.position.maxScrollExtent;
    final targetOffset = (ratio * maxScroll).clamp(0.0, maxScroll);

    _scrollCtrl.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _nextMatch() {
    if (_matchIndices.isEmpty) return;
    final newIdx = (_currentMatchIndex + 1) % _matchIndices.length;
    setState(() => _currentMatchIndex = newIdx);
    _scrollToMatch(newIdx);
  }

  /// 简洁加载指示器 — 无持续动画，避免与 FadeTransition 叠加掉帧
  Widget _buildLoadingIndicator(AppTheme theme) {
    // 加载骨架屏：模拟文档结构，视觉过渡更平滑
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题骨架
            Container(
              height: 28,
              width: double.infinity * 0.6,
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 20),
            // 正文骨架行
            ...List.generate(8, (i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                height: 16,
                width: double.infinity * (0.4 + (i % 3) * 0.2),
                decoration: BoxDecoration(
                  color: theme.textSecondary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            )),
            const Spacer(),
            // 底部加载提示
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: theme.primaryColor.withValues(alpha: 0.5),
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '正在加载...',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: theme.textSecondary.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _prevMatch() {
    if (_matchIndices.isEmpty) return;
    final newIdx =
        (_currentMatchIndex - 1 + _matchIndices.length) % _matchIndices.length;
    setState(() => _currentMatchIndex = newIdx);
    _scrollToMatch(newIdx);
  }

  Widget _buildContent({double topPadding = 72}) {
    final tp = ThemeProvider.of(context);
    final theme = tp.currentTheme;
    final isDark = theme.brightness == Brightness.dark;

    final topPad = MediaQuery.of(context).padding.top +
        topPadding +
        (_isSearching ? 56 : 0);

    if (!_isMarkdown) {
      // 非 Markdown：纯文本显示
      return SingleChildScrollView(
        controller: _scrollCtrl,
        padding: EdgeInsets.fromLTRB(20, topPad, 20,
            MediaQuery.of(context).padding.bottom + 32),
        child: SelectableText(
          _content,
          style: GoogleFonts.jetBrainsMono(
            fontSize: tp.fontSize,
            color: theme.textSecondary,
            height: tp.lineHeight,
          ),
        ),
      );
    }

    // 搜索高亮模式
    if (_searchQuery.isNotEmpty && _matchIndices.isNotEmpty) {
      final lowerQuery = _searchQuery.toLowerCase();
      final lines = _content.split('\n');
      final processedLines = <String>[];
      bool inCodeBlock = false;
      for (final line in lines) {
        if (line.trimLeft().startsWith('```')) {
          inCodeBlock = !inCodeBlock;
          processedLines.add(line);
          continue;
        }
        if (inCodeBlock || line.startsWith('|')) {
          processedLines.add(line);
        } else if (line.toLowerCase().contains(lowerQuery)) {
          processedLines.add('🔍 $line');
        } else {
          processedLines.add(line);
        }
      }
      final highlightedContent = processedLines.join('\n');
      return Markdown(
        key: ValueKey('md_search_${globalThemeVersion.value}'),
        data: highlightedContent,
        controller: _scrollCtrl,
        padding: EdgeInsets.fromLTRB(
            20, topPad, 20, MediaQuery.of(context).padding.bottom + 32),
        selectable: true,
        styleSheet: _buildMarkdownStyleSheet(),
      );
    }

    // 普通 Markdown 渲染
    return Markdown(
      key: ValueKey('md_${globalThemeVersion.value}'),
      data: _content,
      controller: _scrollCtrl,
      padding: EdgeInsets.fromLTRB(
          20, topPad, 20, MediaQuery.of(context).padding.bottom + 32),
      selectable: true,
      styleSheet: _buildMarkdownStyleSheet(),
    );
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
                )
              : const SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.dark,
                ),
          child: Scaffold(
            extendBody: true,
            extendBodyBehindAppBar: true,
            body: AnimatedGradientBg(
              child: _loading
                  ? _buildLoadingIndicator(theme)
                  : FadeTransition(
                      opacity: _fadeAnimation,
                      child: Stack(
                      children: [
                        // 内容
                        SafeArea(
                          top: false,
                          bottom: false,
                          child: _isEditing
                              ? const SizedBox()
                              : _buildContent(),
                        ),

                        // 编辑模式
                        if (_isEditing)
                          SafeArea(
                            bottom: false,
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                16,
                                MediaQuery.of(context).padding.top + 72,
                                16,
                                MediaQuery.of(context).padding.bottom + 16,
                              ),
                              child: GlassCard(
                                borderRadius: 16,
                                padding: EdgeInsets.zero,
                                color: isDark
                                    ? const Color(0xFF0D0D1A)
                                        .withValues(alpha: 0.85)
                                    : Colors.white.withValues(alpha: 0.85),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : theme.primaryColor
                                          .withValues(alpha: 0.12),
                                ),
                                child: TextField(
                                  controller: _editController,
                                  maxLines: null,
                                  expands: true,
                                  textAlignVertical: TextAlignVertical.top,
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: tp.fontSize,
                                    color: theme.textSecondary,
                                    height: tp.lineHeight,
                                  ),
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.all(16),
                                    border: InputBorder.none,
                                    hintText: '在此编辑内容...',
                                    hintStyle: GoogleFonts.inter(
                                      color: theme.textSecondary
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  cursorColor: theme.primaryColor,
                                ),
                              ),
                            ),
                          ),

                        // 顶部栏（平滑动画）
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOutQuint,
                          top: _showAppBar
                              ? 0
                              : -(MediaQuery.of(context).padding.top + 72),
                          left: 0,
                          right: 0,
                          child: SafeArea(
                            bottom: false,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                              child: GlassAppBar(
                                child: _isEditing
                                    ? _buildEditAppBar()
                                    : _isSearching
                                        ? _buildSearchAppBar()
                                        : _buildNormalAppBar(),
                              ),
                            ),
                          ),
                        ),

                        // 返回顶部 FAB
                        Positioned(
                          bottom: MediaQuery.of(context).padding.bottom + 24,
                          right: 20,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            switchInCurve: Curves.elasticOut,
                            switchOutCurve: Curves.easeInBack,
                            transitionBuilder: (child, anim) {
                              return FadeTransition(
                                opacity: anim,
                                child: ScaleTransition(
                                  scale: Tween<double>(begin: 0.3, end: 1.0)
                                      .animate(CurvedAnimation(
                                    parent: anim,
                                    curve: Curves.elasticOut,
                                  )),
                                  child: child,
                                ),
                              );
                            },
                            child: _showBackToTop && !_isEditing
                                ? GlassFAB(
                                    key: const ValueKey('back_to_top'),
                                    onTap: () {
                                      _backToTopHideTimer?.cancel();
                                      _scrollCtrl.animateTo(
                                        0,
                                        duration:
                                            const Duration(milliseconds: 500),
                                        curve: Curves.easeOut,
                                      );
                                      setState(
                                          () => _showBackToTop = false);
                                    },
                                    child: const SizedBox(
                                      width: 52,
                                      height: 52,
                                      child: Icon(
                                          Icons.keyboard_arrow_up_rounded,
                                          color: Colors.white,
                                          size: 28),
                                    ),
                                  )
                                : const SizedBox.shrink(
                                    key: ValueKey('no_back_to_top')),
                          ),
                        ),
                      ],
                    ),
                  ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNormalAppBar() {
    final tp = ThemeProvider.of(context);
    final theme = tp.currentTheme;

    return Row(
      children: [
        GlassIconButton(
          icon: Icons.arrow_back_rounded,
          onTap: () => Navigator.pop(context),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _title,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: theme.textColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (!_isMarkdown)
                Text(
                  getFileTypeLabel(widget.filePath),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: theme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        GlassIconButton(
          icon: Icons.search_rounded,
          onTap: _toggleSearch,
        ),
        const SizedBox(width: 4),
        GlassIconButton(
          icon: Icons.edit_rounded,
          onTap: _enterEditMode,
        ),
      ],
    );
  }

  Widget _buildEditAppBar() {
    final tp = ThemeProvider.of(context);
    final theme = tp.currentTheme;

    return Row(
      children: [
        GlassIconButton(
          icon: Icons.close_rounded,
          onTap: _exitEditMode,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFD54F),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '编辑中',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: theme.textColor,
                ),
              ),
            ],
          ),
        ),
        ScaleOnTap(
          scaleAmount: 0.94,
          onTap: _saveFile,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Material(
                color: theme.primaryColor.withValues(alpha: 0.3),
                child: InkWell(
                  onTap: _saveFile,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.save_rounded,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          '保存',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAppBar() {
    final tp = ThemeProvider.of(context);
    final theme = tp.currentTheme;
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        Row(
          children: [
            GlassIconButton(
              icon: Icons.close_rounded,
              onTap: _toggleSearch,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : theme.primaryColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextField(
                  controller: _searchController,
                  style:
                      GoogleFonts.inter(fontSize: 14, color: theme.textColor),
                  decoration: InputDecoration(
                    hintText: '搜索...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 14,
                      color: theme.textSecondary.withValues(alpha: 0.4),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  cursorColor: theme.primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _matchIndices.isEmpty
                  ? '无匹配'
                  : '${_currentMatchIndex + 1}/${_matchIndices.length}',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: theme.textSecondary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 4),
            GlassIconButton(
              icon: Icons.keyboard_arrow_up_rounded,
              onTap: _prevMatch,
            ),
            const SizedBox(width: 2),
            GlassIconButton(
              icon: Icons.keyboard_arrow_down_rounded,
              onTap: _nextMatch,
            ),
          ],
        ),
      ],
    );
  }

  /// 构建自定义 Markdown 样式表
  MarkdownStyleSheet _buildMarkdownStyleSheet() {
    final tp = ThemeProvider.of(context);
    final theme = tp.currentTheme;
    final fs = tp.fontSize;
    final lh = tp.lineHeight;
    final ls = tp.letterSpacing;
    final isDark = theme.brightness == Brightness.dark;
    final isAurora = theme.id == 'aurora';

    final bodyColor = isAurora
        ? const Color(0xFFC8F0DC)
        : isDark
            ? theme.textSecondary
            : const Color(0xFF334155);
    final headingColor = isAurora
        ? const Color(0xFFE8FFF4)
        : isDark
            ? theme.textColor
            : const Color(0xFF1E293B);
    final strongColor = isAurora
        ? const Color(0xFFFFFFFF)
        : isDark
            ? theme.textColor
            : const Color(0xFF1E293B);
    final codeTextColor = isAurora
        ? const Color(0xFF6EE7B7)
        : isDark
            ? const Color(0xFFCE93D8)
            : theme.primaryColor;
    final linkColor = isAurora
        ? const Color(0xFFA5F3C4)
        : isDark
            ? const Color(0xFF64B5F6)
            : theme.primaryColor;
    final codeBgColor = isAurora
        ? const Color(0xFF6EE7B7).withValues(alpha: 0.08)
        : isDark
            ? Colors.white.withValues(alpha: 0.06)
            : theme.primaryColor.withValues(alpha: 0.07);
    final codeBlockBgColor = isAurora
        ? const Color(0xFF0A1929).withValues(alpha: 0.85)
        : isDark
            ? theme.primaryColor.withValues(alpha: 0.04)
            : const Color(0xFFF8FAFC);
    final codeBlockBorderColor = isAurora
        ? const Color(0xFF6EE7B7).withValues(alpha: 0.15)
        : isDark
            ? theme.primaryColor.withValues(alpha: 0.08)
            : theme.primaryColor.withValues(alpha: 0.10);
    final blockquoteBorderColor = isAurora
        ? const Color(0xFF818CF8).withValues(alpha: 0.5)
        : theme.primaryColor.withValues(alpha: 0.4);
    final blockquoteBgColor = isAurora
        ? const Color(0xFF818CF8).withValues(alpha: 0.06)
        : theme.primaryColor.withValues(alpha: 0.04);
    final blockquoteTextColor = isAurora
        ? const Color(0xFFC0D0F0)
        : isDark
            ? theme.textSecondary.withValues(alpha: 0.7)
            : const Color(0xFF475569);
    final bulletColor = isAurora
        ? const Color(0xFF6EE7B7)
        : theme.primaryColor;
    final h3Color = isAurora
        ? const Color(0xFF818CF8)
        : isDark
            ? theme.accentColor
            : theme.primaryColor;
    final h4Color = isAurora
        ? const Color(0xFF6EE7B7)
        : theme.primaryColor;
    final tableHeadColor = isAurora
        ? const Color(0xFFE8FFF4)
        : isDark
            ? theme.textColor
            : const Color(0xFF1E293B);
    final tableBodyColor = isAurora
        ? const Color(0xFFC8F0DC)
        : isDark
            ? theme.textSecondary
            : const Color(0xFF334155);

    return MarkdownStyleSheet(
      h1: GoogleFonts.inter(
        fontSize: fs + 13,
        fontWeight: FontWeight.w800,
        color: headingColor,
        height: 1.4,
      ).copyWith(
        shadows: isAurora
            ? [
                Shadow(
                    color:
                        const Color(0xFF6EE7B7).withValues(alpha: 0.35),
                    blurRadius: 28),
                Shadow(
                    color:
                        const Color(0xFF818CF8).withValues(alpha: 0.15),
                    blurRadius: 40),
              ]
            : [
                Shadow(
                    color: theme.primaryColor.withValues(alpha: 0.15),
                    blurRadius: 12),
              ],
      ),
      h2: GoogleFonts.inter(
        fontSize: fs + 7,
        fontWeight: FontWeight.w700,
        color: headingColor,
        height: 1.4,
      ),
      h3: GoogleFonts.inter(
        fontSize: fs + 3,
        fontWeight: FontWeight.w700,
        color: h3Color,
        height: 1.4,
      ),
      h4: GoogleFonts.inter(
        fontSize: fs + 1,
        fontWeight: FontWeight.w600,
        color: h4Color,
        height: 1.4,
      ),
      p: GoogleFonts.inter(
        fontSize: fs,
        height: lh,
        letterSpacing: ls,
        color: bodyColor,
      ),
      strong: GoogleFonts.inter(
        fontSize: fs,
        fontWeight: FontWeight.w700,
        color: strongColor,
      ),
      em: GoogleFonts.inter(
        fontSize: fs,
        fontStyle: FontStyle.italic,
        color: bodyColor,
      ),
      a: GoogleFonts.inter(
        color: linkColor,
        fontSize: fs,
        decoration: TextDecoration.underline,
        decorationColor: linkColor.withValues(alpha: 0.4),
      ),
      code: GoogleFonts.jetBrainsMono(
        fontSize: fs - 2,
        color: codeTextColor,
        backgroundColor: codeBgColor,
      ),
      codeblockDecoration: BoxDecoration(
        color: codeBlockBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: codeBlockBorderColor),
      ),
      codeblockPadding: const EdgeInsets.all(16),
      blockquote: GoogleFonts.inter(
        fontSize: fs - 1,
        color: blockquoteTextColor,
        fontStyle: FontStyle.italic,
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: blockquoteBorderColor, width: 3),
        ),
        color: blockquoteBgColor,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      blockquotePadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      listBullet: GoogleFonts.inter(
        fontSize: fs,
        color: bulletColor,
      ),
      listIndent: 24,
      tableHead: GoogleFonts.inter(
        fontSize: fs - 2,
        fontWeight: FontWeight.w700,
        color: tableHeadColor,
      ),
      tableBody: GoogleFonts.inter(
        fontSize: fs - 2,
        color: tableBodyColor,
      ),
      tableBorder: TableBorder.all(
        color: theme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      tableCellsPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.primaryColor.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';

import '../models/app_theme.dart';
import '../models/remote_file.dart';
import '../pages/home_page.dart';
import '../providers/theme_provider.dart';
import '../services/preferences_service.dart';
import '../services/webdav_service.dart';
import '../widgets/animated_gradient_bg.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_icon_button.dart';
import '../widgets/scale_on_tap.dart';

/// 网络存储页面 — WebDAV 客户端
///
/// v6.1.0: 新增目录进出滑动动画、面包屑路径导航、列表过渡动画
class NetworkStoragePage extends StatefulWidget {
  final String storageType;

  const NetworkStoragePage({super.key, required this.storageType});

  @override
  State<NetworkStoragePage> createState() => _NetworkStoragePageState();
}

class _NetworkStoragePageState extends State<NetworkStoragePage>
    with TickerProviderStateMixin {
  bool _connected = false;
  bool _connecting = false;
  String? _error;
  bool _rememberPassword = true;

  // 动画控制器
  late AnimationController _fileListAnimController;
  late Animation<double> _fileListAnim;
  late AnimationController _errorAnimController;
  late Animation<Offset> _errorAnim;
  late AnimationController _navAnimController;
  late Animation<double> _navAnim;

  // WebDAV 字段
  final _webdavUrl = TextEditingController();
  final _webdavUser = TextEditingController();
  final _webdavPass = TextEditingController();
  WebDavService? _webdavService;
  String _currentPath = '/';

  final List<RemoteFile> _files = [];

  // 目录导航历史栈（支持滑动返回）
  final List<String> _pathHistory = [];

  // 列表项滑动过渡 key
  int _listKey = 0;

  @override
  void initState() {
    super.initState();

    _fileListAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fileListAnim = CurvedAnimation(
      parent: _fileListAnimController,
      curve: Curves.easeOutCubic,
    );

    _errorAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _errorAnim = TweenSequence<Offset>([
      TweenSequenceItem(
          tween: Tween<Offset>(begin: Offset.zero, end: const Offset(0.05, 0)),
          weight: 2),
      TweenSequenceItem(
          tween: Tween<Offset>(
              begin: const Offset(0.05, 0), end: const Offset(-0.05, 0)),
          weight: 2),
      TweenSequenceItem(
          tween: Tween<Offset>(
              begin: const Offset(-0.05, 0), end: const Offset(0.05, 0)),
          weight: 2),
      TweenSequenceItem(
          tween: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero),
          weight: 2),
    ]).animate(CurvedAnimation(
        parent: _errorAnimController, curve: Curves.easeInOut));

    // 导航过渡动画（目录切换时路径栏淡入淡出）
    _navAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _navAnim = CurvedAnimation(
      parent: _navAnimController,
      curve: Curves.easeOutCubic,
    );

    _loadSavedWebdavInfo();
  }

  Future<void> _loadSavedWebdavInfo() async {
    final savedUrl = PreferencesService.webdavUrl;
    final savedUser = PreferencesService.webdavUsername;
    final savedPass = PreferencesService.webdavPassword;
    final savedRemember = PreferencesService.webdavRemember;
    if (savedUrl.isNotEmpty) {
      _webdavUrl.text = savedUrl;
      _webdavUser.text = savedUser;
      _webdavPass.text = savedPass;
      _rememberPassword = savedRemember;
      if (mounted) setState(() {});
    }
  }

  Future<void> _saveWebdavInfo() async {
    await PreferencesService.setWebdavCredentials(
      url: _webdavUrl.text.trim(),
      username: _webdavUser.text.trim(),
      password: _webdavPass.text,
      remember: _rememberPassword,
    );
  }

  Future<void> _clearSavedWebdavInfo() async {
    await PreferencesService.clearWebdavCredentials();
    _webdavUrl.clear();
    _webdavUser.clear();
    _webdavPass.clear();
    _rememberPassword = true;
    setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已清除保存的连接信息',
              style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: Colors.redAccent.withValues(alpha: 0.8),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  void dispose() {
    _webdavUrl.dispose();
    _webdavUser.dispose();
    _webdavPass.dispose();
    _fileListAnimController.dispose();
    _errorAnimController.dispose();
    _navAnimController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _connecting = true;
      _error = null;
    });
    _errorAnimController.reset();

    try {
      debugPrint('[WebDAV] 开始连接: ${_webdavUrl.text}');
      var url = _webdavUrl.text.trim();
      final user = _webdavUser.text.trim();
      final pass = _webdavPass.text;

      if (url.isEmpty) throw Exception('请输入服务器地址');
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'http://$url';
      }
      if (url.endsWith('/')) url = url.substring(0, url.length - 1);

      final uri = Uri.tryParse(url);
      if (uri == null || uri.host.isEmpty) {
        throw Exception('服务器地址格式不正确，请检查输入');
      }

      _webdavService = WebDavService(
        baseUrl: url,
        username: user,
        password: pass,
      );

      final list = await _webdavService!.propfind('/');
      _files.clear();
      _files.addAll(list);
      _currentPath = '/';
      _pathHistory.clear();
      _listKey++;

      await _saveWebdavInfo();
      if (mounted) {
        _navAnimController.forward(from: 0);
        _fileListAnimController.forward(from: 0);
        setState(() {
          _connecting = false;
          _connected = true;
        });
      }
    } catch (e) {
      debugPrint('[WebDAV] 连接失败: $e');
      String errorMsg;
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (msg.contains('Failed host lookup') ||
          msg.contains('DNS') ||
          msg.contains('无法解析')) {
        errorMsg = '无法解析服务器地址，请检查域名是否正确或网络连接';
      } else if (msg.contains('timed out') ||
          msg.contains('Timeout') ||
          msg.contains('超时')) {
        errorMsg = '连接超时，请检查服务器地址和网络连接';
      } else if (msg.contains('认证失败') ||
          msg.contains('401') ||
          msg.contains('403')) {
        errorMsg = '用户名或密码错误，请重新输入';
      } else if (msg.contains('Connection refused') ||
          msg.contains('拒绝')) {
        errorMsg = '服务器拒绝连接，请检查端口或服务是否启动';
      } else {
        errorMsg = msg;
      }
      if (mounted) {
        setState(() {
          _connecting = false;
          _connected = false;
          _error = errorMsg;
        });
        _errorAnimController.forward(from: 0);
      }
    }
  }

  /// 进入子目录（带动画）
  Future<void> _navigateDir(String dirName) async {
    if (_webdavService == null) return;
    final newPath = _currentPath.endsWith('/')
        ? '$_currentPath$dirName'
        : '$_currentPath/$dirName';
    try {
      final list = await _webdavService!.propfind(newPath);
      _pathHistory.add(_currentPath);
      if (mounted) {
        _files.clear();
        _files.addAll(list);
        _listKey++;
        _currentPath = newPath.endsWith('/') ? newPath : '$newPath/';
        _fileListAnimController.forward(from: 0);
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法打开文件夹: $e')),
        );
      }
    }
  }

  Future<void> _downloadAndOpen(RemoteFile file) async {
    if (_webdavService == null) return;
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('正在下载: ${file.name}'),
          duration: const Duration(seconds: 30),
        ),
      );
      final remotePath = _currentPath.endsWith('/')
          ? '$_currentPath${file.name}'
          : '$_currentPath/${file.name}';
      final tempDir = await getTemporaryDirectory();
      final localPath = '${tempDir.path}/_amber_webdav_${file.name}';
      await _webdavService!.downloadFile(remotePath, localPath);
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        Navigator.pushNamed(context, '/reader', arguments: {
          'path': localPath,
          'fileType': getFileType(localPath),
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败: $e')),
        );
      }
    }
  }

  /// 返回上一级目录（带动画）
  Future<void> _goBack() async {
    if (_webdavService == null || _pathHistory.isEmpty) {
      _disconnect();
      return;
    }
    final previousPath = _pathHistory.removeLast();
    await _navigateToPath(previousPath);
  }

  /// 刷新当前目录
  Future<void> _refresh() async {
    if (_webdavService == null) return;
    await _navigateToPath(_currentPath);
  }

  /// 导航到指定路径（内部用，带列表动画）
  Future<void> _navigateToPath(String path) async {
    if (_webdavService == null) return;
    try {
      final list = await _webdavService!.propfind(path);
      if (mounted) {
        _files.clear();
        _files.addAll(list);
        _listKey++;
        _currentPath = path.endsWith('/') ? path : '$path/';
        _fileListAnimController.forward(from: 0);
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导航失败: $e')),
        );
      }
    }
  }

  Future<void> _disconnect() async {
    setState(() {
      _connected = false;
      _files.clear();
      _currentPath = '/';
      _pathHistory.clear();
      _webdavService = null;
    });
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
              child: SafeArea(
                child: Column(
                  children: [
                    // 顶部栏
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      child: GlassCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            GlassIconButton(
                              icon: Icons.arrow_back_rounded,
                              onTap: _connected
                                  ? _disconnect
                                  : () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.cloud_rounded,
                                color: theme.primaryColor, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _connected ? 'WebDAV' : '网络存储',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: theme.textColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_connected) ...[
                              GlassIconButton(
                                icon: Icons.refresh_rounded,
                                onTap: _refresh,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 内容区
                    Expanded(
                      child: _connected
                          ? _buildFileList(theme, isDark)
                          : _buildLoginForm(theme, isDark),
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

  Widget _buildLoginForm(AppTheme theme, bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        MediaQuery.of(context).padding.bottom + 40,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 服务器地址
          Text(
            '服务器地址',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.textSecondary.withValues(alpha: 0.6),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          GlassCard(
            borderRadius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _webdavUrl,
              style: GoogleFonts.inter(
                  fontSize: 14, color: theme.textColor),
              decoration: InputDecoration(
                hintText: '例如: https://dav.example.com',
                hintStyle: GoogleFonts.inter(
                  fontSize: 14,
                  color: theme.textSecondary.withValues(alpha: 0.3),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                isDense: true,
                prefixIcon: Icon(Icons.dns_rounded,
                    color: theme.primaryColor, size: 20),
              ),
              cursorColor: theme.primaryColor,
              keyboardType: TextInputType.url,
            ),
          ),
          const SizedBox(height: 20),

          // 用户名
          Text(
            '用户名',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.textSecondary.withValues(alpha: 0.6),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          GlassCard(
            borderRadius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _webdavUser,
              style: GoogleFonts.inter(
                  fontSize: 14, color: theme.textColor),
              decoration: InputDecoration(
                hintText: '输入用户名',
                hintStyle: GoogleFonts.inter(
                  fontSize: 14,
                  color: theme.textSecondary.withValues(alpha: 0.3),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                isDense: true,
                prefixIcon: Icon(Icons.person_rounded,
                    color: theme.primaryColor, size: 20),
              ),
              cursorColor: theme.primaryColor,
            ),
          ),
          const SizedBox(height: 20),

          // 密码
          Text(
            '密码',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.textSecondary.withValues(alpha: 0.6),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          GlassCard(
            borderRadius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _webdavPass,
              obscureText: true,
              style: GoogleFonts.inter(
                  fontSize: 14, color: theme.textColor),
              decoration: InputDecoration(
                hintText: '输入密码',
                hintStyle: GoogleFonts.inter(
                  fontSize: 14,
                  color: theme.textSecondary.withValues(alpha: 0.3),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                isDense: true,
                prefixIcon: Icon(Icons.lock_rounded,
                    color: theme.primaryColor, size: 20),
              ),
              cursorColor: theme.primaryColor,
            ),
          ),
          const SizedBox(height: 12),

          // 记住密码 + 清除信息
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(
                    () => _rememberPassword = !_rememberPassword),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _rememberPassword
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      color: _rememberPassword
                          ? theme.primaryColor
                          : theme.textSecondary.withValues(alpha: 0.4),
                      size: 22,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '记住密码',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: _rememberPassword
                            ? theme.textColor
                            : theme.textSecondary.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _clearSavedWebdavInfo,
                child: Text(
                  '清除保存',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.redAccent.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 连接按钮
          ScaleOnTap(
            onTap: _connecting ? null : _connect,
            child: GlassCard(
              borderRadius: 14,
              padding: EdgeInsets.zero,
              color: theme.primaryColor.withValues(alpha: 0.15),
              border: Border.all(
                  color: theme.primaryColor.withValues(alpha: 0.3)),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                width: double.infinity,
                child: Center(
                  child: _connecting
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: theme.primaryColor,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.link_rounded,
                                color: theme.primaryColor, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              '连接',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: theme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),

          // 错误信息
          if (_error != null) ...[
            const SizedBox(height: 16),
            SlideTransition(
              position: _errorAnim,
              child: GlassCard(
                borderRadius: 12,
                padding: const EdgeInsets.all(14),
                color: Colors.redAccent.withValues(alpha: 0.1),
                border: Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.2)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline_rounded,
                        color: Colors.redAccent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 从当前路径中提取面包屑段
  List<String> _getBreadcrumbSegments() {
    final parts = _currentPath.split('/')..removeWhere((s) => s.isEmpty);
    return parts;
  }

  Widget _buildFileList(AppTheme theme, bool isDark) {
    return Column(
      children: [
        // 面包屑路径导航栏（简洁淡入淡出，无横向滑动抖动）
        FadeTransition(
          opacity: _navAnim,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GlassCard(
                borderRadius: 12,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Row(
                  children: [
                    // 返回上级按钮
                    if (_pathHistory.isNotEmpty)
                      ScaleOnTap(
                        onTap: _goBack,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(Icons.arrow_back_rounded,
                              color: theme.primaryColor, size: 18),
                        ),
                      ),
                    if (_pathHistory.isNotEmpty)
                      const SizedBox(width: 4),
                    // 面包屑
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            // 根目录
                            _buildBreadcrumbItem(
                              '根目录',
                              _currentPath == '/',
                              () async {
                                if (_webdavService == null) return;
                                await _navigateToPath('/');
                              },
                              theme,
                            ),
                            // 中间路径段
                            ..._buildBreadcrumbItems(theme),
                          ],
                        ),
                      ),
                    ),
                    // 刷新按钮
                    ScaleOnTap(
                      onTap: _refresh,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.refresh_rounded,
                            color: theme.textSecondary
                                .withValues(alpha: 0.5),
                            size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // 文件列表（淡入过渡，不使用横向滑动）
        Expanded(
          child: _files.isEmpty
              ? FadeTransition(
                  opacity: _fileListAnim,
                  child: Center(
                    child: Text(
                      '空文件夹',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: theme.textSecondary.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                )
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: child,
                    );
                  },
                  child: ListView.builder(
                    key: ValueKey('file_list_$_listKey'),
                    padding: EdgeInsets.fromLTRB(
                      20,
                      0,
                      20,
                      MediaQuery.of(context).padding.bottom + 40,
                    ),
                    itemCount: _files.length,
                    itemBuilder: (context, index) {
                      final file = _files[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ScaleOnTap(
                          onTap: file.isDirectory
                              ? () => _navigateDir(file.name)
                              : () => _downloadAndOpen(file),
                          child: GlassCard(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Icon(
                                  file.isDirectory
                                      ? Icons.folder_rounded
                                      : Icons.insert_drive_file_rounded,
                                  color: file.isDirectory
                                      ? theme.primaryColor
                                      : theme.accentColor,
                                  size: 22,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    file.name,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: theme.textColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (file.isDirectory)
                                  Icon(Icons.chevron_right_rounded,
                                      color: theme.textSecondary
                                          .withValues(alpha: 0.3),
                                      size: 20),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  /// 构建面包屑路径段
  List<Widget> _buildBreadcrumbItems(AppTheme theme) {
    final segments = _getBreadcrumbSegments();
    final items = <Widget>[];

    String accumulatedPath = '';
    for (int i = 0; i < segments.length; i++) {
      accumulatedPath += '/${segments[i]}';
      final isLast = i == segments.length - 1;
      final segmentPath = '$accumulatedPath/';

      if (items.isNotEmpty) {
        items.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(Icons.chevron_right_rounded,
                color: theme.textSecondary.withValues(alpha: 0.25),
                size: 16),
          ),
        );
      }

      items.add(
        _buildBreadcrumbItem(
          segments[i],
          isLast && _currentPath.endsWith('/') &&
              _currentPath == '$accumulatedPath/',
          isLast && _currentPath == segmentPath
              ? null
              : () async {
                  await _navigateToPath(segmentPath);
                },
          theme,
        ),
      );
    }

    return items;
  }

  /// 单个面包屑段
  Widget _buildBreadcrumbItem(
    String label,
    bool isActive,
    VoidCallback? onTap,
    AppTheme theme,
  ) {
    return ScaleOnTap(
      onTap: isActive ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive)
              Container(
                height: 6,
                width: 6,
                decoration: BoxDecoration(
                  color: theme.primaryColor,
                  shape: BoxShape.circle,
                ),
              ),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive
                    ? theme.textColor
                    : theme.textSecondary.withValues(alpha: 0.6),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

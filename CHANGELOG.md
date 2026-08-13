# Changelog

本项目按 [Semantic Versioning](https://semver.org/lang/zh-CN/) 记录版本变化。

## [Unreleased]

当前源码版本：`6.3.0+630`。

### Added

- 保存每个文档的阅读进度，并在最近文档中显示进度。
- 重新打开文档时恢复上次阅读位置。
- WebDAV 自签名证书兼容开关，默认保持严格证书校验。
- WebDAV 与偏好设置服务自动化测试。

### Changed

- 增加未保存修改保护，退出编辑前进行确认。
- 强化 WebDAV 凭据、连接地址和目录状态处理。
- CI 增加格式检查、静态分析和测试。

## [6.2.0] - 2026-05-20

### Added

- WebDAV 测试连接、最近连接记录和上次目录记忆。
- WebDAV 地址协议补全与路径规范化。

### Fixed

- 修复下载提示偶发无法消失的问题。
- 修复主题切换时路由栈被重建的问题。
- 缩短普通提示停留时间，减少阅读遮挡。

## [6.1.4] - 2026-04-17

### Fixed

- 优化空文档缩放及光晕同步效果。
- 改进 WebDAV 下载状态提示。

## [6.0.2] - 2026-04-17

### Fixed

- 修复部分 WebDAV 服务的重定向兼容问题。

[Unreleased]: https://github.com/YXX168/Amber-MD/compare/v6.1.4...HEAD
[6.2.0]: https://github.com/YXX168/Amber-MD/compare/v6.1.4...993bb8e
[6.1.4]: https://github.com/YXX168/Amber-MD/releases/tag/v6.1.4
[6.0.2]: https://github.com/YXX168/Amber-MD/releases/tag/v6.0.2

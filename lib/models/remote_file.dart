/// 远程文件数据类（用于 WebDAV）
class RemoteFile {
  final String name;
  final bool isDirectory;

  const RemoteFile(this.name, this.isDirectory);
}

/// 应用内更新 —— 配置区（你通常只需要改这一处）
///
/// 发新版本时，一共改 3 个地方：
///   1) pubspec.yaml 里的 version（如 1.0.0+1 → 1.0.1+2）
///   2) 本文件的 kCurrentVersion，必须和上面保持一致
///   3) 把新 APK 传到 GitHub Releases，并把下载链接填进 version_check.json 的 downloadUrl
///
/// version_check.json 推荐直接提交到你的 GitHub 仓库根目录，用 raw 链接：
///   https://raw.githubusercontent.com/<用户名>/<仓库>/<分支>/version_check.json
/// 模板见仓库根目录的 version_check.json（改完再提交）。
const String kCurrentVersion = '1.0.7';

/// version_check.json 的真实路径（不含协议前缀，由下方镜像列表逐个拼接后尝试）
const String kVersionCheckPath =
    'raw.githubusercontent.com/lcy631zz/goodnight/main/version_check.json';

/// 多个 GitHub 反向代理镜像，按顺序尝试；最后一个 '' 表示直连（兜底，国内通常不通）。
/// 任一镜像可达即可完成版本检查；下载地址也会自动换成当前成功的镜像，保证下载也走通的线路。
const List<String> kGhProxyMirrors = [
  'https://ghproxy.net/https://',
  'https://ghproxy.com/https://',
  'https://ghproxy.io/https://',
  'https://mirror.ghproxy.com/https://',
  '',
];

/// 必须与 Android 端 MainActivity.kt 里的 CHANNEL 字符串保持一致
const String kAppUpdateChannel = 'com.goodnight.goodnight/app_update';

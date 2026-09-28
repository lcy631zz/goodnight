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
const String kCurrentVersion = '1.0.0';

/// version_check.json 的远程地址（必须改成你自己的，否则永远检测不到更新）
/// 做法：把 version_check.json 提交到你的 GitHub 仓库，再用它的 raw 链接：
///   https://raw.githubusercontent.com/<你的用户名>/<你的仓库>/main/version_check.json
/// 注意：GitHub 新仓库默认分支是 main；若你的仓库分支叫 master，把末尾的 main 改成 master。
const String kVersionCheckUrl =
    'https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/version_check.json';

/// 必须与 Android 端 MainActivity.kt 里的 CHANNEL 字符串保持一致
const String kAppUpdateChannel = 'com.goodnight.goodnight/app_update';

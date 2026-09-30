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
const String kCurrentVersion = '1.0.3';

/// version_check.json 的远程地址（已替换为真实仓库）
/// 已改为：GitHub 账号 lcy631zz，仓库名 goodnight，分支 main。
/// 若你建仓库时用了别的名字，把下面 lcy631zz/goodnight 改掉即可。
const String kVersionCheckUrl =
    'https://raw.githubusercontent.com/lcy631zz/goodnight/main/version_check.json';

/// 必须与 Android 端 MainActivity.kt 里的 CHANNEL 字符串保持一致
const String kAppUpdateChannel = 'com.goodnight.goodnight/app_update';

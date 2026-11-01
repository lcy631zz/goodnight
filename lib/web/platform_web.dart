// 仅在 Web 平台编译时包含（通过调用方的条件导入）。
// 切勿在 native（Android/iOS/桌面）构建中直接引入 dart:html。
import 'dart:html' as html;

/// 当前运行环境是否为「安卓设备的浏览器」。
/// 用于网页版判断是否提示用户下载安卓 App。
/// 注意：不能用 defaultTargetPlatform（桌面 Chrome 会被误判为 android），
/// 必须看 userAgent 里是否含 "android"。
bool get isAndroidWeb =>
    html.window.navigator.userAgent.toLowerCase().contains('android');

/// 在新标签页打开外部链接（如 APK 下载地址）。仅 Web 使用。
void openExternalUrl(String url) => html.window.open(url, '_blank');

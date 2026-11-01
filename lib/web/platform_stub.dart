// 非 Web 平台（Android/iOS/桌面 App）的占位实现。
// 条件导入保证 native 构建不会引入 dart:html，从而编译通过。
bool get isAndroidWeb => false;

void openExternalUrl(String url) {}

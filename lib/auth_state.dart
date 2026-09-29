import 'package:flutter/foundation.dart';

/// 全局登录态通知。
///
/// 登录/登出时由 [SupabaseBackend] 更新其 `value`；
/// 任何依赖登录态的界面（消息、我的等）订阅后，会在登录/登出时自动刷新，
/// 解决「在一个板块登录后，其他板块仍显示需要登录」的问题。
///
/// 注意：本机会话真正持久化在 shared_preferences 的 `current_user` 里，
/// 这里只负责「状态变化广播」，不替代持久化。
final authUserNotifier = ValueNotifier<String?>(null);

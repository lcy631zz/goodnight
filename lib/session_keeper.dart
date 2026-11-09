import 'dart:async';
import 'package:flutter/material.dart';
import 'db.dart';
import 'nav_key.dart';
import 'screens/login.dart';

/// 登录态守护器。
///
/// 在 MainScreen.initState 调用 [startSessionKeeper] 一次即可（App 生命周期内常驻）。
/// 它会周期性（默认 30s）校验本机会话令牌是否仍与数据库一致：
///   - 一致 → 正常；
///   - 不一致/不存在 → 说明该 (账号, 设备类型) 已被同类型新设备登录顶掉，
///     于是强制登出并弹出登录页（带「已被挤下线」提示）。
///
/// 这是「惰性踢出」：旧设备在下一次校验时才发现被顶，无需实时长连接，足够内测期使用。
Timer? _timer;
bool _kicked = false;

void startSessionKeeper() {
  _timer?.cancel();
  _timer = Timer.periodic(const Duration(seconds: 30), (_) => _check());
  _check(); // 启动后立即校验一次
}

void stopSessionKeeper() {
  _timer?.cancel();
  _timer = null;
}

Future<void> _check() async {
  final user = await DB.getCurrentUser();
  if (user == null) {
    _kicked = false; // 未登录，复位标记，等待下次登录
    return;
  }
  bool ok;
  try {
    ok = await DB.validateSession();
  } catch (_) {
    // 网络抖动 / 后端暂不可达：等下一轮再校验，绝不能把请求失败误判成「被顶掉」。
    return;
  }
  if (ok) {
    _kicked = false;
    return;
  }
  // 会话已失效（被顶掉或已登出）→ 强制下线
  if (_kicked) return; // 已经弹过登录页，避免重复 push
  _kicked = true;
  await DB.logout();
  final state = navigatorKey.currentState;
  if (state != null) {
    state.push(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(canPop: false, kicked: true),
      ),
    );
  }
}

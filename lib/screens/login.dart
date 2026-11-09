import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../db.dart';
import '../ui.dart';
import '../web/platform_stub.dart'
    if (dart.library.html) '../web/platform_web.dart';

const primary = Color(0xFF3B6FE0);
const subColor = Color(0xFF8A90A2);
const textColor = Color(0xFF1F2330);
const bgColor = Color(0xFFF4F5F7);

/// 安卓 App 下载地址（走 ghproxy 镜像，国内可下）。
/// 发布新版本时需同步更新版本号（与 version_check.json 的 downloadUrl 保持一致）。
const String _apkDownloadUrl =
    'https://ghproxy.net/https://github.com/lcy631zz/goodnight/releases/download/v1.0.7/goodnight.apk';

/// 账号登录页（不支持自注册，账号由管理员/花名册预置）。
/// 登录成功后 pop(true)，调用方据此刷新界面。
class LoginScreen extends StatefulWidget {
  /// false 时隐藏返回按钮（首次进入必须登录才能用）。
  final bool canPop;
  const LoginScreen({super.key, this.canPop = true});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  String? _err;
  bool _loading = false; // 登录中显示转圈，防止重复点击

  void _submit() async {
    final u = _user.text.trim();
    final p = _pass.text;
    if (u.length < 2) {
      setState(() => _err = '账号至少 2 个字');
      return;
    }
    // 登录不限制密码长度：初始密码是 5 位 csucid，老账号又有 6 / 8 位，
    // 在这里卡最小长度只会误拦；凭证是否正确交给后端按哈希精确比对。
    if (p.isEmpty) {
      setState(() => _err = '请输入密码');
      return;
    }
    setState(() => _loading = true);
    try {
      final ok = await DB.login(u, p);
      if (!ok) {
        setState(() => _err = '账号或密码错误');
        return;
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      // 旧包没有这层捕获，登录请求一旦抛异常就表现为"点了没反应"。
      // 现在把错误显示出来，便于区分是网络问题还是凭证问题。
      if (mounted) setState(() => _err = '登录失败：${friendlyError(e)}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.canPop
          ? AppBar(
              leading: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back)),
              title: const Text('登录'),
            )
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 28),
            const Text('欢迎回来',
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 6),
            const Text('登录你的账号',
                style: TextStyle(fontSize: 13, color: subColor)),
            const SizedBox(height: 28),
            _field(_user, '输入csucid', false),
            const SizedBox(height: 14),
            _field(_pass, '输入密码', true),
            const SizedBox(height: 8),
            const Text('初始密码默认为你的 csucid，登录后可在「设置」修改。',
                style: TextStyle(fontSize: 12, color: subColor)),
            if (_err != null) ...[
              const SizedBox(height: 12),
              Text(_err!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: Colors.white),
                      )
                    : const Text('登录',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
            if (kIsWeb && isAndroidWeb) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.android_rounded, color: primary, size: 22),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        '安卓用户：下载 App 体验更流畅',
                        style: TextStyle(fontSize: 13, color: textColor),
                      ),
                    ),
                    TextButton(
                      onPressed: () => openExternalUrl(_apkDownloadUrl),
                      style: TextButton.styleFrom(
                        foregroundColor: primary,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      child: const Text('下载',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, bool obscure) {
    return TextField(
      controller: c,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: subColor),
        filled: true,
        fillColor: bgColor,
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

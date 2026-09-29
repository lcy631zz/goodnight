import 'package:flutter/material.dart';
import '../db.dart';

const primary = Color(0xFF3B6FE0);
const subColor = Color(0xFF8A90A2);
const textColor = Color(0xFF1F2330);
const bgColor = Color(0xFFF4F5F7);

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
      setState(() => _err = '用户名至少 2 个字');
      return;
    }
    if (p.length < 6) {
      setState(() => _err = '密码至少 6 位');
      return;
    }
    setState(() => _loading = true);
    try {
      final ok = await DB.login(u, p);
      if (!ok) {
        setState(() => _err = '用户名或密码错误');
        return;
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      // 旧包没有这层捕获，登录请求一旦抛异常就表现为"点了没反应"。
      // 现在把错误显示出来，便于区分是网络问题还是凭证问题。
      if (mounted) setState(() => _err = '登录失败：${e.toString()}');
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
            _field(_user, '用户名', false),
            const SizedBox(height: 14),
            _field(_pass, '密码（至少 6 位）', true),
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

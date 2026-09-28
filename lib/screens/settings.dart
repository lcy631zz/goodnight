import 'package:flutter/material.dart';
import '../models.dart';
import '../db.dart';
import '../lang.dart';
import 'login.dart';
import '../update_service.dart';
import '../widgets/update_dialog.dart';
import '../screens/feedback.dart';

const primary = Color(0xFF3B6FE0);
const subColor = Color(0xFF8A90A2);
const textColor = Color(0xFF1F2330);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  User? _u;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async => _u = await DB.currentUserModel();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('设置'))),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _section(t('语言')),
          Container(
            decoration: _box(),
            child: Row(
              children: [
                Expanded(child: Text(t('简繁切换'), style: const TextStyle(fontSize: 14))),
                SegmentedButton<String>(
                  selected: {Lang.locale},
                  onSelectionChanged: (s) async {
                    await Lang.set(s.first);
                    setState(() {});
                  },
                  segments: [
                    ButtonSegment(value: 'zh-CN', label: Text(t('简体'))),
                    ButtonSegment(value: 'zh-TW', label: Text(t('繁體'))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _section(t('账号')),
          Container(
            decoration: _box(),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t('修改密码'), style: const TextStyle(fontSize: 14)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _changePassword,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _section(t('关于')),
          Container(
            decoration: _box(),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t('当前账号角色'), style: const TextStyle(fontSize: 14)),
                  trailing: Text(
                    t(_u?.roleLabel ?? '普通用户'),
                    style: const TextStyle(color: subColor),
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFECEEF2)),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t('检查更新'), style: const TextStyle(fontSize: 14)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _checkUpdate,
                ),
                const Divider(height: 1, color: Color(0xFFECEEF2)),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t('意见反馈'), style: const TextStyle(fontSize: 14)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const FeedbackScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton(
              onPressed: () async {
                await DB.logout();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false,
                  );
                }
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(t('退出登录'),
                  style: const TextStyle(color: Colors.red)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword() async {
    final oldC = TextEditingController();
    final newC = TextEditingController();
    final confirmC = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('修改密码')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _pw(oldC, t('当前密码')),
            const SizedBox(height: 10),
            _pw(newC, t('新密码（≥6位）')),
            const SizedBox(height: 10),
            _pw(confirmC, t('确认新密码')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('取消'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t('确定')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (newC.text.length < 6) {
      _toast(t('新密码至少 6 位'));
      return;
    }
    if (newC.text != confirmC.text) {
      _toast(t('两次密码不一致'));
      return;
    }
    final me = await DB.getCurrentUser();
    if (me == null) return;
    final done = await DB.changePassword(me, oldC.text, newC.text);
    _toast(done ? t('密码已修改') : t('当前密码错误'));
  }

  Future<void> _checkUpdate() async {
    final info = await fetchLatestVersion();
    if (!mounted) return;
    if (info == null) {
      _toast(t('检查更新失败，请稍后重试'));
      return;
    }
    final res = checkUpdate(info);
    if (res.needUpdate) {
      await showUpdateDialog(context, res);
    } else {
      _toast(t('已经是最新版本'));
    }
  }

  void _toast(String s) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s)));
    }
  }

  Widget _pw(TextEditingController c, String hint) => TextField(
        controller: c,
        obscureText: true,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: subColor),
          filled: true,
          fillColor: const Color(0xFFF4F5F7),
          border: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      );

  Widget _section(String s) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(s,
            style: const TextStyle(
                fontSize: 12, color: subColor, fontWeight: FontWeight.w600)),
      );

  BoxDecoration _box() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      );
}

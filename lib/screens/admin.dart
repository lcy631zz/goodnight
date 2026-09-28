import 'package:flutter/material.dart';
import '../models.dart';
import '../db.dart';
import '../ui.dart';
import '../screens/feedback_admin.dart';
import '../lang.dart';

const primary = Color(0xFF3B6FE0);
const subColor = Color(0xFF8A90A2);
const textColor = Color(0xFF1F2330);

/// 用户管理：仅管理员可见。列出全部用户，可把任意用户设为
/// 普通用户 / 审核 / 管理员。不能修改自己的角色（防止误操作失去管理权）。
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<User> _users = [];
  String? _me;
  bool _isAdmin = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final me = await DB.getCurrentUser();
    final model = me == null ? null : await DB.getUser(me);
    final users = await DB.allUsers();
    if (mounted) {
      setState(() {
        _me = me;
        _isAdmin = model?.role == 'admin';
        _users = users;
        _loading = false;
      });
    }
  }

  Future<void> _setRole(User u, String role) async {
    await DB.setRole(u.username, role);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(t('已设为') + t(u.roleLabel))));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(t('用户管理'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(title: Text(t('用户管理'))),
        body: Center(
          child: Text(t('无权访问'), style: const TextStyle(color: subColor)),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(t('用户管理')),
        actions: [
          IconButton(
            icon: const Icon(Icons.feedback_outlined),
            tooltip: t('用户反馈'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FeedbackAdminScreen()),
            ),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: _users.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _row(_users[i]),
      ),
    );
  }

  Widget _row(User u) {
    final isMe = u.username == _me;
    final roles = const [
      _Role('user', '普通用户'),
      _Role('reviewer', '审核'),
      _Role('admin', '管理员'),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              userAvatar(u, radius: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u.username,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600, color: textColor)),
                    const SizedBox(height: 2),
                    Text(t(u.roleLabel),
                        style: const TextStyle(fontSize: 12, color: subColor)),
                  ],
                ),
              ),
              if (isMe)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F5F7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(t('（本人）'),
                      style: const TextStyle(fontSize: 11, color: subColor)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: roles.map((r) {
              final on = u.role == r.key;
              final disabled = isMe; // 不能改自己
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: ElevatedButton(
                    onPressed: disabled ? null : () => _setRole(u, r.key),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: on ? primary : const Color(0xFFF4F5F7),
                      foregroundColor: on ? Colors.white : const Color(0xFF8A90A2),
                      disabledForegroundColor: on ? Colors.white : const Color(0xFFB8BCC8),
                      disabledBackgroundColor:
                          on ? primary : const Color(0xFFF4F5F7),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                    child: Text(r.label, style: const TextStyle(fontSize: 12)),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _Role {
  final String key;
  final String label;
  const _Role(this.key, this.label);
}

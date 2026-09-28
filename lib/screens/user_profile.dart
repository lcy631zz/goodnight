import 'package:flutter/material.dart';
import '../models.dart';
import '../db.dart';
import '../ui.dart';
import '../lang.dart';
import 'detail.dart';
import 'edit_profile.dart';
import 'chat.dart';
import 'login.dart';

const primary = Color(0xFF3B6FE0);
const subColor = Color(0xFF8A90A2);
const textColor = Color(0xFF1F2330);
const bgColor = Color(0xFFF4F5F7);

class UserProfileScreen extends StatefulWidget {
  final String username;
  const UserProfileScreen({super.key, required this.username});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  User? _u;
  List<Post> _posts = [];
  bool _isMe = false;
  bool _isFriend = false;
  bool _pending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final me = await DB.getCurrentUser();
    _isMe = me == widget.username;
    final u = await DB.getUser(widget.username);
    final all = await DB.allPosts();
    final mine = all.where((p) => p.author == widget.username).toList();
    _isFriend = me != null && await DB.isFriend(me, widget.username);
    if (me != null) {
      _pending = (await DB.outgoingRequests(me))
          .any((r) => r.to == widget.username);
    }
    if (mounted) {
      setState(() {
        _u = u;
        _posts = mine;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_u == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.username)),
        body: Center(child: Text(t('用户不存在'))),
      );
    }
    final u = _u!;
    return Scaffold(
      appBar: AppBar(title: Text(u.username)),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 28, 18, 22),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [primary, Color(0xFF6E8BFF)]),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    userAvatar(u, radius: 34),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(u.username,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          const SizedBox(height: 3),
                          Text(
                            t(u.roleLabel),
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    if (_isMe)
                      ElevatedButton(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const EditProfileScreen()),
                          );
                          _load();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999)),
                        ),
                        child: Text(t('编辑资料')),
                      )
                    else
                      _headerButton(),
                  ],
                ),
                const SizedBox(height: 14),
                if (u.bio != null && u.bio!.isNotEmpty)
                  Text(u.bio!,
                      style: const TextStyle(color: Colors.white)),
                if (u.region != null && u.region!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('📍 ${u.region!}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ],
            ),
          ),
          _infoCard(u),
          _section(t('TA的帖子')),
          if (_posts.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(t('暂无内容'),
                  style: const TextStyle(color: subColor)),
            )
          else
            ..._posts.map((p) => _postCard(p)).toList(),
        ],
      ),
    );
  }

  Widget _headerButton() {
    final style = ElevatedButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
    if (_isFriend) {
      return ElevatedButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ChatScreen(peer: widget.username)),
        ),
        style: style,
        child: Text(t('发消息')),
      );
    }
    if (_pending) {
      return ElevatedButton(
        onPressed: null,
        style: style.copyWith(
          backgroundColor: MaterialStateProperty.all(Colors.white70),
          foregroundColor: MaterialStateProperty.all(subColor),
        ),
        child: Text(t('等待通过')),
      );
    }
    return ElevatedButton(
      onPressed: () async {
        var me = await DB.getCurrentUser();
        if (me == null) {
          final ok = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
          if (ok != true) return;
          me = await DB.getCurrentUser();
        }
        if (me == null) return;
        final ok = await DB.sendFriendRequest(me, widget.username);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ok ? t('好友请求已发送') : t('已发送或已是好友'))));
        _load();
      },
      style: style,
      child: Text(t('加好友')),
    );
  }

  Widget _infoCard(User u) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E6F5)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user, color: primary, size: 16),
              const SizedBox(width: 6),
              Text(t('学生信息'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          _row(t('性别'), u.gender),
          _row(t('专业'), u.major),
          _row(t('级'), u.grade),
        ],
      ),
    );
  }

  Widget _row(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: subColor)),
          ),
          Expanded(
            child: Text(value ?? '-',
                style: const TextStyle(
                    fontSize: 13,
                    color: textColor,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _section(String s) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
        child: Text(s,
            style: const TextStyle(
                fontSize: 12, color: subColor, fontWeight: FontWeight.w600)),
      );

  Widget _postCard(Post p) {
    final c = parseColor(p.color);
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DetailScreen(post: p)),
        );
        _load();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('[${p.board}] ${p.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textColor)),
                  const SizedBox(height: 4),
                  Text('${t('点赞')} ${p.likes} · ${t('浏览')} ${p.views}',
                      style: const TextStyle(fontSize: 11, color: subColor)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

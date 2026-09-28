import 'package:flutter/material.dart';
import '../db.dart';
import '../models.dart';
import '../ui.dart';
import '../lang.dart';
import 'chat.dart';
import 'user_profile.dart';
import 'login.dart';

const primary = Color(0xFF3B6FE0);
const subColor = Color(0xFF8A90A2);
const bgColor = Color(0xFFF4F5F7);
const textColor = Color(0xFF1F2330);

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<Map<String, dynamic>> _convs = [];
  List<String> _friends = [];
  List<FriendRequest> _incoming = [];
  List<FriendRequest> _outgoing = [];
  String? _me;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final me = await DB.getCurrentUser();
    if (me == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final convs = await DB.conversations(me);
    final friends = await DB.friendsOf(me);
    final incoming = await DB.incomingRequests(me);
    final outgoing = await DB.outgoingRequests(me);
    if (mounted) {
      setState(() {
        _me = me;
        _convs = convs;
        _friends = friends;
        _incoming = incoming;
        _outgoing = outgoing;
        _loading = false;
      });
    }
  }

  Future<void> _respond(int id, bool accept) async {
    await DB.respondRequest(id, accept);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_me == null) {
      return Scaffold(
        appBar: AppBar(title: Text(t('消息'))),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔒', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              const Text('登录后才能私信和加好友',
                  style: TextStyle(color: subColor)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ).then((v) => v == true ? _load() : null),
                style: ElevatedButton.styleFrom(backgroundColor: primary),
                child: Text(t('登录')),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(t('消息')),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddFriendScreen()),
            ).then((_) => _load()),
            icon: const Icon(Icons.person_add_alt_1_outlined),
            tooltip: t('添加好友'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              children: [
                if (_incoming.isNotEmpty) ...[
                  _section(t('好友请求')),
                  ..._incoming.map(_requestCard).toList(),
                ],
                _section(t('会话')),
                if (_convs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                        child: Text('暂无会话，去加个好友聊聊吧',
                            style: TextStyle(color: subColor))),
                  )
                else
                  ..._convs.map(_convCard).toList(),
                _section(t('我的好友')),
                if (_friends.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                        child: Text('还没有好友', style: TextStyle(color: subColor))),
                  )
                else
                  ..._friends.map(_friendCard).toList(),
              ],
            ),
    );
  }

  Widget _section(String s) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
        child: Text(s,
            style: const TextStyle(
                fontSize: 12, color: subColor, fontWeight: FontWeight.w600)),
      );

  String _preview(Message m) {
    if (m.recalled) return t('[撤回的消息]');
    if (m.sticker != null) return t('[表情包]');
    if (m.imagePath != null && m.imagePath!.isNotEmpty) return t('[图片]');
    return m.text ?? '';
  }

  Widget _convCard(Map<String, dynamic> c) {
    final peer = c['peer'] as String;
    final last = c['last'] as Message;
    final unread = c['unread'] as int;
    return _row(
      avatar: userAvatarByName(peer, radius: 22),
      title: peer,
      subtitle: _preview(last),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(last.time, style: const TextStyle(fontSize: 11, color: subColor)),
          const SizedBox(height: 4),
          if (unread > 0)
            Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                color: Color(0xFFF25C7E), shape: BoxShape.circle),
              child: Text('$unread',
                  style: const TextStyle(fontSize: 10, color: Colors.white)),
            ),
        ],
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChatScreen(peer: peer)),
      ).then((_) => _load()),
    );
  }

  Widget _friendCard(String name) {
    return FutureBuilder<User?>(
      future: DB.getUser(name),
      builder: (_, snap) {
        final u = snap.data;
        final bio = u?.bio;
        final major = u?.major;
        final grade = u?.grade;
        return _row(
          avatar: userAvatar(u, radius: 20),
          title: name,
          subtitle: (bio != null && bio.isNotEmpty)
              ? bio
              : (major != null ? '$major · $grade' : ''),
          trailing: IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => UserProfileScreen(username: name)),
            ),
            icon: const Icon(Icons.chevron_right, color: subColor),
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ChatScreen(peer: name)),
          ).then((_) => _load()),
        );
      },
    );
  }

  Widget _requestCard(FriendRequest r) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          userAvatarByName(r.from, radius: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.from, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text('${t('向你发来了好友请求')} · ${r.time}',
                    style: const TextStyle(fontSize: 11, color: subColor)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _respond(r.id!, false),
            child: Text(t('拒绝'),
                style: const TextStyle(color: subColor, fontSize: 13)),
          ),
          const SizedBox(width: 6),
          ElevatedButton(
            onPressed: () => _respond(r.id!, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            ),
            child: Text(t('接受'),
                style: const TextStyle(fontSize: 13, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _row({
    required Widget avatar,
    required String title,
    required String subtitle,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            avatar,
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: subColor)),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

/// 添加好友：列出除自己和已好友外的所有用户，可发送请求。
class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({super.key});

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  List<User> _candidates = [];
  List<String> _friends = [];
  List<String> _pendingTo = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final me = await DB.getCurrentUser() ?? '';
    final all = (await DB.allUsers()).where((u) => u.username != me).toList();
    final friends = await DB.friendsOf(me);
    final outgoing = await DB.outgoingRequests(me);
    if (mounted) {
      setState(() {
        _candidates = all;
        _friends = friends;
        _pendingTo = outgoing.map((r) => r.to).toList();
      });
    }
  }

  Future<void> _add(String name) async {
    final me = await DB.getCurrentUser() ?? '';
    final ok = await DB.sendFriendRequest(me, name);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t('好友请求已发送'))));
      _load();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t('已发送或已是好友'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('添加好友'))),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        children: _candidates.map((u) {
          final isFriend = _friends.contains(u.username);
          final pending = _pendingTo.contains(u.username);
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                userAvatar(u, radius: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u.username,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (u.gender != null) u.gender!,
                          if (u.major != null) u.major!,
                          if (u.grade != null) u.grade!,
                        ].join(' · '),
                        style: const TextStyle(fontSize: 11, color: subColor),
                      ),
                    ],
                  ),
                ),
                if (isFriend)
                  const Text('已是好友',
                      style: TextStyle(color: subColor, fontSize: 12))
                else if (pending)
                  const Text('等待通过',
                      style: TextStyle(color: Color(0xFFF5A623), fontSize: 12))
                else
                  ElevatedButton(
                    onPressed: () => _add(u.username),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                    ),
                    child: Text(t('加好友'),
                        style: const TextStyle(fontSize: 13, color: Colors.white)),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

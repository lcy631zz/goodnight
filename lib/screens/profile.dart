import 'package:flutter/material.dart';
import '../models.dart';
import '../db.dart';
import '../ui.dart';
import '../lang.dart';
import 'login.dart';
import 'detail.dart';
import 'settings.dart';
import 'edit_profile.dart';
import 'review.dart';
import 'admin.dart';

const primary = Color(0xFF3B6FE0);
const subColor = Color(0xFF8A90A2);
const textColor = Color(0xFF1F2330);
const bgColor = Color(0xFFF4F5F7);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  String? _me;
  User? _meModel;
  List<Post> _liked = [];
  List<Post> _collected = [];
  List<Post> _mine = [];
  List<Post> _history = [];
  int _totalLikes = 0;
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final me = await DB.getCurrentUser();
    if (me == null) {
      if (mounted) setState(() => _me = null);
      return;
    }
    final model = await DB.getUser(me);
    final mine = await DB.postsByAuthor(me);
    final liked = await DB.postsByIds(await DB.likedIds());
    final collected = await DB.postsByIds(await DB.collectedIds());
    final history = await DB.postsByIds(await DB.historyIds());
    if (mounted) {
      setState(() {
        _me = me;
        _meModel = model;
        _mine = mine;
        _liked = liked;
        _collected = collected;
        _history = history;
        _totalLikes = mine.fold(0, (n, p) => n + p.likes);
      });
    }
  }

  Future<void> _logout() async {
    await DB.logout();
    if (mounted) {
      setState(() {
        _me = null;
        _meModel = null;
        _liked = [];
        _collected = [];
        _mine = [];
        _history = [];
        _totalLikes = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_me == null) return _loggedOut();
    final u = _meModel!;
    return Scaffold(
      appBar: AppBar(
        title: Text(t('我的')),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ).then((_) => _load()),
            icon: const Icon(Icons.settings),
            tooltip: t('设置'),
          ),
          TextButton(
            onPressed: _logout,
            child: Text(t('退出登录'),
                style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
      body: Column(
        children: [
          _header(u),
          _stats(),
          _infoCard(u),
          if (u.role == 'admin')
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminScreen()),
              ).then((_) => _load()),
              child: Container(
                margin: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE0E6F5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.manage_accounts,
                        color: primary, size: 18),
                    const SizedBox(width: 10),
                    Text(t('用户管理'),
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    const Icon(Icons.chevron_right, color: subColor),
                  ],
                ),
              ),
            ),
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tab,
              labelColor: primary,
              unselectedLabelColor: subColor,
              indicatorColor: primary,
              labelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
              tabs: [
                Tab(text: t('点赞记录')),
                Tab(text: t('收藏')),
                Tab(text: t('我的帖子')),
                Tab(text: t('历史记录')),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _list(_liked, t('还没有点赞过的帖子')),
                _list(_collected, t('还没有收藏的帖子')),
                _list(_mine, t('你还没有发过帖子')),
                _list(_history, t('还没有浏览记录')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _loggedOut() {
    return Scaffold(
      appBar: AppBar(title: Text(t('我的'))),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 56, color: subColor),
            const SizedBox(height: 16),
            const Text('登录后才能发帖、点赞、收藏',
                style: TextStyle(color: textColor, fontSize: 15)),
            const SizedBox(height: 20),
            SizedBox(
              width: 200,
              height: 46,
              child: ElevatedButton(
                onPressed: () async {
                  final ok = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const LoginScreen(canPop: true)),
                  );
                  if (ok == true) _load();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(t('登录'),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(User u) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [primary, Color(0xFF6E8BFF)]),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
            ).then((_) => _load()),
            child: userAvatar(u, radius: 34),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              ).then((_) => _load()),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(u.username,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      const SizedBox(width: 8),
                      if (u.canReview)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(t(u.roleLabel),
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.white)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text('网络安全 · 大一',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white70)),
                  if (u.region != null && u.region!.isNotEmpty)
                    Text('📍 ${u.region!}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white70)),
                ],
              ),
            ),
          ),
          OutlinedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
            ).then((_) => _load()),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999)),
              foregroundColor: Colors.white,
            ),
            child: Text(t('编辑资料')),
          ),
        ],
      ),
    );
  }

  Widget _stats() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          )
        ],
      ),
      child: Row(
        children: [
          _stat('${_mine.length}', t('帖子')),
          _stat('$_totalLikes', t('获赞')),
          _stat('${_collected.length}', t('收藏')),
        ],
      ),
    );
  }

  Widget _stat(String n, String l) => Expanded(
        child: Column(
          children: [
            Text(n,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(l, style: const TextStyle(fontSize: 11, color: subColor)),
          ],
        ),
      );

  Widget _infoCard(User u) {
    final row = (String k, String? v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              SizedBox(
                width: 96,
                child: Text(k,
                    style: const TextStyle(fontSize: 13, color: subColor)),
              ),
              Expanded(
                child: Text(v ?? '-',
                    style: const TextStyle(
                        fontSize: 13,
                        color: textColor,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E6F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_user, color: primary, size: 16),
              SizedBox(width: 6),
              Text('学生信息',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          row(t('性别'), u.gender),
          row(t('专业'), u.major),
          row(t('级'), u.grade),
        ],
      ),
    );
  }

  Widget _list(List<Post> posts, String emptyTip) {
    if (posts.isEmpty) {
      return Center(
        child: Text(emptyTip, style: const TextStyle(color: subColor)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: posts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final p = posts[i];
        return GestureDetector(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => DetailScreen(post: p)),
            );
            _load();
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('[${p.board}] ${p.title}',
                          style: const TextStyle(fontSize: 13, height: 1.5)),
                    ),
                    if (p.sold)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('已售',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey)),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Text('${t('浏览')} ${p.views} · ${t('点赞')} ${p.likes} · ${p.time}',
                    style: const TextStyle(fontSize: 11, color: subColor)),
              ],
            ),
          ),
        );
      },
    );
  }
}

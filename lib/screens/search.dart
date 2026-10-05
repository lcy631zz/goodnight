import 'package:flutter/material.dart';
import '../models.dart';
import '../db.dart';
import '../ui.dart';
import '../lang.dart';
import 'detail.dart';
import 'user_profile.dart';

const primary = Color(0xFF3B6FE0);
const subColor = Color(0xFF8A90A2);
const textColor = Color(0xFF1F2330);
const bgColor = Color(0xFFF4F5F7);

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _q = TextEditingController();
  List<Post> _all = [];
  List<User> _users = [];
  List<Post> _postResults = [];
  List<User> _userResults = [];
  int _tab = 0; // 0 帖子, 1 用户

  @override
  void initState() {
    super.initState();
    _load();
    _q.addListener(_apply);
  }

  Future<void> _load() async {
    _all = await DB.allPosts();
    _users = await DB.allUsers();
    _apply();
  }

  void _apply() {
    final q = _q.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() {
        _postResults = [];
        _userResults = [];
      });
      return;
    }
    setState(() {
      _postResults = _all.where((p) {
        return p.title.toLowerCase().contains(q) ||
            p.body.toLowerCase().contains(q) ||
            p.board.toLowerCase().contains(q) ||
            p.author.toLowerCase().contains(q);
      }).toList();
      _userResults = _users.where((u) {
        final hay = [
          u.username,
          u.bio ?? '',
          u.major ?? '',
          u.grade ?? '',
          u.region ?? '',
          u.gender ?? '',
        ].join(' ').toLowerCase();
        return hay.contains(q);
      }).toList();
    });
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('搜索'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(999),
              ),
              child: TextField(
                controller: _q,
                decoration: InputDecoration.collapsed(
                  hintText: t('搜索帖子、用户…'),
                  hintStyle: const TextStyle(color: subColor),
                ),
              ),
            ),
          ),
          // 分段切换：帖子 / 用户
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                _seg('帖子', 0),
                const SizedBox(width: 8),
                _seg('用户', 1),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _q.text.trim().isEmpty
                ? const Center(
                    child: Text('输入关键词开始搜索',
                        style: TextStyle(color: subColor)),
                  )
                : _tab == 0
                    ? _postList()
                    : _userList(),
          ),
        ],
      ),
    );
  }

  Widget _seg(String label, int idx) {
    final sel = _tab == idx;
    return GestureDetector(
      onTap: () => setState(() => _tab = idx),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? primary : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: sel ? null : Border.all(color: const Color(0xFFECEEF2)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                color: sel ? Colors.white : subColor,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _postList() {
    if (_postResults.isEmpty) {
      return const Center(
          child: Text('没有找到相关帖子', style: TextStyle(color: subColor)));
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      itemCount: _postResults.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final p = _postResults[i];
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
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => UserProfileScreen(username: p.author)),
                  ),
                  child: userAvatarByName(p.author, radius: 22),
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
                      Text(
                          '${p.author} · ${t('点赞')} ${p.likes} · ${t('浏览')} ${p.views}',
                          style: const TextStyle(
                              fontSize: 11, color: subColor)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _userList() {
    if (_userResults.isEmpty) {
      return const Center(
          child: Text('没有找到相关用户', style: TextStyle(color: subColor)));
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      itemCount: _userResults.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final u = _userResults[i];
        final sub = (u.bio != null && u.bio!.isNotEmpty)
            ? u.bio!
            : [u.major, u.grade, u.region]
                .where((e) => e != null && e!.isNotEmpty)
                .map((e) => e!)
                .join(' · ');
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => UserProfileScreen(username: u.username)),
          ),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                userAvatar(u, radius: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u.username,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: textColor)),
                      if (sub.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(sub,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11, color: subColor)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

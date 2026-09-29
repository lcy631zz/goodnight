import 'package:flutter/material.dart';
import '../models.dart';
import '../db.dart';
import '../ui.dart';
import '../lang.dart';
import 'search.dart';
import 'detail.dart';
import 'user_profile.dart';

const primary = Color(0xFF3B6FE0);
const textColor = Color(0xFF1F2330);
const subColor = Color(0xFF8A90A2);
const bgColor = Color(0xFFF4F5F7);

/// 文字笔记封面用的板块 emoji（模仿小红书纯文字笔记的图标感）。
const Map<String, String> _boardEmoji = {
  '校园圈': '🏫',
  '黑市': '🛒',
  '拼车': '🚗',
  '招募': '📣',
  '招领': '🔎',
  '问答': '❓',
};

class HomeScreen extends StatefulWidget {
  final VoidCallback onPublish;
  const HomeScreen({super.key, required this.onPublish});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  List<Post> _posts = [];
  String _board = ''; // 空 = 推荐流（默认首页）
  final _allBoards = const ['校园圈', '黑市', '拼车', '招募', '招领', '问答'];
  List<({Post post, String reason})> _feed = [];
  final Map<int, String> _reasons = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> refresh() async => _load();

  Future<void> _load() async {
    if (_board.isEmpty) {
      _feed = await DB.recommendFeed();
      _posts = _feed.map((e) => e.post).toList();
      _reasons.clear();
      for (final e in _feed) {
        if (e.post.id != null) _reasons[e.post.id!] = e.reason;
      }
    } else {
      final all = await DB.allPosts();
      all.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
      _posts = all.where((p) => p.board == _board).toList();
      _reasons.clear();
    }
    // 一次性取回我的点赞/收藏，再本地匹配——
    // 之前对每条帖子调 DB.decorate（各发 2 个网络请求），20 帖=40 次往返，是首页卡顿的大头。
    final likedSet = (await DB.likedIds()).toSet();
    final collectedSet = (await DB.collectedIds()).toSet();
    for (final p in _posts) {
      p.liked = likedSet.contains(p.id);
      p.collected = collectedSet.contains(p.id);
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final list = _board.isEmpty
        ? _posts
        : _posts.where((p) => p.board == _board).toList();

    final left = <Post>[], right = <Post>[];
    for (int i = 0; i < list.length; i++) {
      (i.isEven ? left : right).add(list[i]);
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(t('goodnight'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchScreen()),
            ),
            child: Text(t('搜索'),
                style: const TextStyle(color: primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Column(
        children: [
          _chips(),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Text(t('暂无内容'),
                        style: const TextStyle(color: subColor)),
                  )
                : SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child: Column(
                                  children: left.map(_card).toList())),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Column(
                                  children: right.map(_card).toList())),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chips() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        height: 34,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: _allBoards.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final n = _allBoards[i];
            final on = n == _board;
            return GestureDetector(
              onTap: () {
                setState(() => _board = n);
                _load();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: on ? primary : bgColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(n,
                    style: TextStyle(
                        color: on ? Colors.white : subColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _card(Post p) {
    final c = parseColor(p.color);
    final dark = Color.fromARGB(
      255,
      (c.red - 40).clamp(0, 255),
      (c.green - 40).clamp(0, 255),
      (c.blue - 40).clamp(0, 255),
    );
    final hasImg = p.images.isNotEmpty;
    final coverH = hasImg ? (100 + ((p.id ?? 0) % 5) * 12).toDouble() : 132.0;
    final reason = _board.isEmpty ? (_reasons[p.id] ?? '') : '';
    return GestureDetector(
      onTap: () async {
        final changed = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DetailScreen(post: p)),
        );
        if (changed == true) _load();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: coverH,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: hasImg
                    ? DecorationImage(
                        image: adaptiveImage(p.images.first),
                        fit: BoxFit.cover)
                    : null,
                gradient: hasImg
                    ? null
                    : LinearGradient(
                        colors: [c, dark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
              ),
              alignment: Alignment.bottomLeft,
              padding: hasImg ? const EdgeInsets.all(8) : const EdgeInsets.all(12),
              child: hasImg
                  ? Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, Colors.black45],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      alignment: Alignment.bottomLeft,
                      child: Text(p.imageCaption,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.22),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(p.board,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Text(p.title,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  height: 1.3)),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(_boardEmoji[p.board] ?? '📌',
                              style: TextStyle(fontSize: 40, color: Colors.white.withOpacity(0.22))),
                        ),
                      ],
                    ),
            ),
            if (reason.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(left: 4, top: 6, bottom: 2),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(reason,
                    style: const TextStyle(color: Colors.white, fontSize: 10)),
              ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: hasImg
                  ? Text(p.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                          height: 1.4))
                  : Text(p.body.isEmpty ? p.title : p.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF5A6072),
                          height: 1.45)),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => _openUser(p.author),
                    child: Row(
                      children: [
                        FutureBuilder<User?>(
                          future: DB.getUser(p.author),
                          builder: (_, s) => userAvatar(s.data, radius: 9),
                        ),
                        const SizedBox(width: 5),
                        Text(p.author,
                            style: const TextStyle(fontSize: 11, color: subColor)),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.favorite_border,
                          size: 13, color: subColor),
                      const SizedBox(width: 3),
                      Text('${p.likes}',
                          style: const TextStyle(fontSize: 11, color: subColor)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openUser(String username) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserProfileScreen(username: username)),
    );
  }
}

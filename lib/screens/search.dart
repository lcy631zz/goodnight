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
  List<Post> _results = [];

  @override
  void initState() {
    super.initState();
    _load();
    _q.addListener(_apply);
  }

  Future<void> _load() async {
    _all = await DB.allPosts();
    _apply();
  }

  void _apply() {
    final q = _q.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() {
      _results = _all.where((p) {
        return p.title.toLowerCase().contains(q) ||
            p.body.toLowerCase().contains(q) ||
            p.board.toLowerCase().contains(q) ||
            p.author.toLowerCase().contains(q);
      }).toList();
    });
  }

  Color _toColor(String hex) => parseColor(hex);

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
          Expanded(
            child: _q.text.trim().isEmpty
                ? const Center(
                    child: Text('输入关键词开始搜索',
                        style: TextStyle(color: subColor)),
                  )
                : _results.isEmpty
                    ? const Center(
                        child: Text('没有找到相关帖子',
                            style: TextStyle(color: subColor)),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        itemCount: _results.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final p = _results[i];
                          return GestureDetector(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => DetailScreen(post: p)),
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
                                          builder: (_) => UserProfileScreen(
                                              username: p.author)),
                                    ),
                                    child: userAvatarByName(p.author,
                                        radius: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                                fontSize: 11,
                                                color: subColor)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

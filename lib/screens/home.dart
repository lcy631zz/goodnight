import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
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

    // 小红书式瀑布流：按估算高度把卡片贪心放进较矮的一列，
    // 两栏错落（不再是旧的按索引奇偶硬分，那种分法两栏会一边特别长）。
    final left = <Post>[], right = <Post>[];
    double lh = 0, rh = 0;
    for (final p in list) {
      final h = _estCardHeight(p);
      if (lh <= rh) {
        left.add(p);
        lh += h;
      } else {
        right.add(p);
        rh += h;
      }
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

  /// 瀑布流分列用的卡片高度估算（无需等图片真实尺寸，纯布局估算）。
  double _estCardHeight(Post p) {
    final colW = (MediaQuery.of(context).size.width - 24) / 2;
    if (p.images.isNotEmpty || p.videos.isNotEmpty) {
      return colW * 4 / 3 + 84; // 3:4 封面 + 标题两行 + 作者行
    }
    return 216; // 纯文字渐变卡
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
    final hasImg = p.images.isNotEmpty;
    final hasVid = p.videos.isNotEmpty;
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
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias, // 封面吃圆角
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------- 封面：图片 / 视频首帧 / 纯文字渐变 ----------
            if (hasImg)
              AspectRatio(
                // 3:4 竖图封面（小红书风）。旧的固定 100~148px 会把图裁得只剩一条。
                aspectRatio: 3 / 4,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image(
                      image: adaptiveImage(p.images.first),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: bgColor,
                        child: const Icon(Icons.broken_image,
                            size: 36, color: subColor),
                      ),
                    ),
                    if (p.imageCaption.isNotEmpty)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding:
                              const EdgeInsets.fromLTRB(10, 20, 10, 8),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.transparent, Colors.black45],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                          child: Text(p.imageCaption,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    if (hasVid)
                      const Center(
                        child: Icon(Icons.play_circle_fill,
                            color: Colors.white, size: 44),
                      ),
                  ],
                ),
              )
            else if (hasVid)
              _VideoPreview(url: p.videos.first)
            else
              _textCover(p),
            // ---------- 推荐理由 ----------
            if (reason.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(left: 10, top: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(reason,
                    style: const TextStyle(color: Colors.white, fontSize: 10)),
              ),
            // ---------- 标题 / 摘要 ----------
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: Text(
                (hasImg || hasVid) ? p.title : (p.body.isEmpty ? p.title : p.body),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: (hasImg || hasVid)
                    ? const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                        height: 1.4)
                    : const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF5A6072),
                        height: 1.45),
              ),
            ),
            // ---------- 作者 / 点赞 ----------
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
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
                            style:
                                const TextStyle(fontSize: 11, color: subColor)),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.favorite_border,
                          size: 13, color: subColor),
                      const SizedBox(width: 3),
                      Text('${p.likes}',
                          style:
                              const TextStyle(fontSize: 11, color: subColor)),
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

  /// 纯文字帖的渐变封面卡（无图无视频时）。
  Widget _textCover(Post p) {
    final c = parseColor(p.color);
    final dark = Color.fromARGB(
      255,
      (c.red - 40).clamp(0, 255),
      (c.green - 40).clamp(0, 255),
      (c.blue - 40).clamp(0, 255),
    );
    return Container(
      height: 148,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c, dark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
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
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
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
                style: TextStyle(
                    fontSize: 40, color: Colors.white.withOpacity(0.22))),
          ),
        ],
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

/// 首页视频卡的首帧预览：初始化后停在第一帧（不自动播放），
/// 外面套 3:4 竖图框 + 播放角标，和图片卡保持同一观感。
class _VideoPreview extends StatefulWidget {
  final String url;
  const _VideoPreview({required this.url});

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  VideoPlayerController? _c;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _c = c;
    c.initialize().then((_) {
      if (mounted) setState(() => _ready = true);
    }).catchError((_) {
      if (mounted) setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = _ready ? _c!.value.size : Size.zero;
    final hasFrame = _ready && size.width > 0 && size.height > 0;
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: const Color(0xFFEDEFF3)),
          if (hasFrame)
            // cover 裁切进 3:4 框：FittedBox + 视频原始尺寸
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: VideoPlayer(_c!), // 已初始化未播放 = 停在首帧
              ),
            )
          else if (_failed)
            const Center(
                child: Icon(Icons.videocam_off, size: 36, color: subColor))
          else
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          if (hasFrame)
            const Center(
              child: Icon(Icons.play_circle_fill,
                  color: Colors.white, size: 44),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../models.dart';
import '../db.dart';
import '../moderation.dart';
import '../ui.dart';
import '../lang.dart';
import 'login.dart';
import 'user_profile.dart';
import '../widgets/compose.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

const primary = Color(0xFF3B6FE0);
const textColor = Color(0xFF1F2330);
const subColor = Color(0xFF8A90A2);
const likeColor = Color(0xFFF25C7E);
const bgColor = Color(0xFFF4F5F7);

/// 文字笔记封面用的板块 emoji（模仿小红书纯文字笔记的图标感）。
const Map<String, String> _detailBoardEmoji = {
  '校园圈': '🏫',
  '黑市': '🛒',
  '拼车': '🚗',
  '招募': '📣',
  '招领': '🔎',
  '问答': '❓',
};
String _boardEmojiOf(String board) => _detailBoardEmoji[board] ?? '📌';

class DetailScreen extends StatefulWidget {
  final Post post;
  const DetailScreen({super.key, required this.post});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late Post _p;
  String? _replyName;
  List<int>? _replyPath;
  List<String> _friends = [];
  bool _loadingFriends = true;
  String? _me;
  bool _isAdmin = false;
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _p = widget.post;
    DB.getCurrentUser().then((me) {
      _me = me;
      if (me != null && _p.id != null) DB.addHistory(_p.id!);
      if (mounted) setState(() {});
    });
    DB.isAdmin().then((a) {
      _isAdmin = a;
      if (mounted) setState(() {});
    });
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    final me = await DB.getCurrentUser() ?? '';
    _friends = me.isEmpty ? [] : await DB.friendsOf(me);
    if (mounted) setState(() => _loadingFriends = false);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  int _count(List<Comment> list) =>
      list.fold(0, (n, c) => n + 1 + _count(c.replies));

  List<Comment> _targetReplies() {
    if (_replyPath == null) return _p.comments;
    List<Comment> node = _p.comments;
    for (final idx in _replyPath!) {
      node = node[idx].replies;
    }
    return node;
  }

  Future<void> _send(
      {String? text, String? imagePath, String? sticker}) async {
    final hasContent = (text ?? '').trim().isNotEmpty ||
        imagePath != null ||
        sticker != null;
    if (!hasContent) return;
    var me = await DB.getCurrentUser();
    if (me == null) {
      final logged = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      if (logged != true) return;
      me = await DB.getCurrentUser();
    }
    if (me == null) return;
    var uncertain = false;
    if (text != null && text.trim().isNotEmpty) {
      final review = Moderator.check(text);
      if (review.status == ModStatus.blocked) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(review.reason ?? t('内容未通过审核'))),
        );
        return;
      }
      uncertain = review.status == ModStatus.uncertain;
    }
    final cm = Comment(
      name: me,
      text: text ?? '',
      imagePath: imagePath,
      sticker: sticker,
      uncertain: uncertain,
    );
    // 乐观更新：先把回复加进内存并立即刷新，让回复立刻可见；
    // 若后续落库失败再回滚，避免“点了没反应”的静默失败。
    final target = _targetReplies();
    target.add(cm);
    _replyPath = null;
    _replyName = null;
    setState(() {});
    try {
      if (uncertain) {
        try {
          await DB.addReport(Report(
            type: 'comment',
            targetId: _p.id!,
            commentId: cm.id,
            reporter: 'bot',
            source: 'bot',
            reason: t('边界词触发，已放行但待人工复核'),
          ));
        } catch (_) {
          // 进审核队列失败不阻塞评论本身（评论已正常显示），仅提示
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(t('提示：进审核队列失败，内容已发布'))),
            );
          }
        }
      }
      await DB.updatePost(_p);
      // 成功：从服务端重新拉取，确保嵌套回复与服务器完全一致。
      final fresh = await DB.postById(_p.id!, includeHidden: true);
      if (fresh != null && mounted) _p = fresh;
      if (mounted) setState(() {});
    } catch (e) {
      // 失败：回滚乐观更新，并展示真实错误（不再静默吞掉）。
      target.remove(cm);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 8),
            content: Text('评论发送失败：${e.toString()}'),
          ),
        );
      }
    }
  }

  void _setReply(List<int> path, String name) {
    setState(() {
      _replyPath = path;
      _replyName = name;
    });
  }

  Future<void> _save() async => DB.updatePost(_p);

  bool get _isAuthor => _me == _p.author;

  /// 谁能删贴：发布者本人删自己的贴，或管理员删任意贴。
  bool get _canDelete => _isAuthor || _isAdmin;

  /// 黑市贴主专属：标记已售出 / 重新上架（仿闲鱼）。
  Widget _soldAction() {
    final sold = _p.sold;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _toggleSold,
        icon: Icon(sold ? Icons.replay : Icons.check_circle_outline),
        label: Text(sold ? t('重新上架') : t('标记已售出')),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: sold ? primary : Colors.orange),
          foregroundColor: sold ? primary : Colors.orange,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Future<void> _toggleSold() async {
    if (_p.id == null) return;
    final next = !_p.sold;
    setState(() => _p.sold = next);
    try {
      await DB.setPostSold(_p.id!, next);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(next
                ? t('已标记已售出，该商品不再被推荐')
                : t('已重新上架'))));
      }
    } catch (e) {
      setState(() => _p.sold = !next);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t('操作失败，请检查网络'))));
      }
    }
  }

  /// 闲鱼风「已售出」印章浮层。
  Widget _soldOverlay() => Center(
        child: Transform.rotate(
          angle: -0.3,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 3),
              borderRadius: BorderRadius.circular(8),
              color: Colors.black38,
            ),
            child: const Text('已售出',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold)),
          ),
        ),
      );

  Future<void> _toggleLike() async {
    final me = await DB.getCurrentUser();
    if (me == null) {
      final logged = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      if (logged != true) return;
    }
    setState(() {
      _p.liked = !_p.liked;
      _p.likes += _p.liked ? 1 : -1;
    });
    await DB.toggleLike(_p.id!, _p.liked);
    await DB.updatePost(_p);
  }

  Future<void> _toggleCollect() async {
    final me = await DB.getCurrentUser();
    if (me == null) {
      final logged = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      if (logged != true) return;
    }
    setState(() => _p.collected = !_p.collected);
    await DB.toggleCollect(_p.id!, _p.collected);
    await DB.updatePost(_p);
  }

  Future<void> _reportPost() async {
    var me = await DB.getCurrentUser();
    if (me == null) {
      final logged = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      if (logged != true) return;
      me = await DB.getCurrentUser();
    }
    if (me == null) return;
    final reason = await _reportDialog();
    if (reason == null) return;
    await DB.addReport(Report(
      type: 'post',
      targetId: _p.id!,
      reporter: me,
      reason: reason,
      source: 'user',
    ));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('已举报，等待管理员审核'))),
      );
    }
  }

  Future<String?> _reportDialog() async {
    String txt = '';
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('举报')),
        content: TextField(
          onChanged: (v) => txt = v,
          decoration: InputDecoration(hintText: t('举报理由（选填）')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('取消')),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, txt.isEmpty ? t('其他') : txt),
            child: Text(t('提交')),
          ),
        ],
      ),
    );
  }

  /// 删除评论（发布者/管理员可删任意评论，评论作者也可删自己那条；含其下所有回复）。
  /// 乐观删除，落库失败则从服务端恢复并提示。
  Future<void> _deleteComment(Comment c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('删除评论')),
        content: Text(t('确定删除这条评论吗？其下的回复也会一并删除')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('取消')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok != true || _p.id == null) return;
    final removed = _removeCommentAt(_p.comments, c.id);
    if (removed && mounted) setState(() {});
    try {
      await DB.removeComment(_p.id!, c.id);
    } catch (e) {
      // 失败：从服务端拉回真实评论树，并提示真实错误
      try {
        final fresh = await DB.postById(_p.id!, includeHidden: true);
        if (fresh != null && mounted) setState(() => _p = fresh);
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 8),
            content: Text('${t('删除失败')}：${e.toString()}'),
          ),
        );
      }
    }
  }

  /// 在评论树中递归移除指定 id 的评论（含其回复）；返回是否移除成功。
  bool _removeCommentAt(List<Comment> list, int cid) {
    for (int i = 0; i < list.length; i++) {
      if (list[i].id == cid) {
        list.removeAt(i);
        return true;
      }
      if (_removeCommentAt(list[i].replies, cid)) return true;
    }
    return false;
  }

  /// 举报别人的评论（进管理员审核队列）。
  Future<void> _reportComment(Comment c) async {
    var me = await DB.getCurrentUser();
    if (me == null) {
      final logged = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      if (logged != true) return;
      me = await DB.getCurrentUser();
    }
    if (me == null) return;
    final reason = await _reportDialog();
    if (reason == null) return;
    try {
      await DB.addReport(Report(
        type: 'comment',
        targetId: _p.id!,
        commentId: c.id,
        reporter: me,
        reason: reason,
        source: 'user',
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('已举报，等待管理员审核'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 8),
            content: Text('${t('举报失败')}：${e.toString()}'),
          ),
        );
      }
    }
  }

  /// 删除帖子：作者删自己的贴，或管理员删任意贴。二次确认，真删除不可恢复。
  Future<void> _deletePost() async {
    if (_p.id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('删除帖子')),
        content: Text(_isAdmin && !_isAuthor
            ? t('确定要删除这条帖子吗？此操作不可恢复。')
            : t('确定要删除你发布的这条帖子吗？此操作不可恢复。')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('取消')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t('删除'),
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await DB.deletePost(_p.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('已删除'))),
        );
        Navigator.pop(context, true); // 返回并通知列表刷新
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t('删除失败')}: ${e.toString()}')),
        );
      }
    }
  }

  Widget _commentContent(Comment c) {
    if (c.sticker != null) {
      return Text(c.sticker!, style: const TextStyle(fontSize: 40));
    }
    if (c.imagePath != null && c.imagePath!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image(image: adaptiveImage(c.imagePath!),
            width: 140, height: 140, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.broken_image, size: 40, color: subColor)),
      );
    }
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 13, color: textColor),
        children: mentionSpans(
          c.text,
          base: const TextStyle(fontSize: 13, color: textColor),
          mentionStyle: const TextStyle(
            fontSize: 13, color: primary, fontWeight: FontWeight.w600),
          onMention: (name) async {
            final u = await DB.getUser(name);
            if (u != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => UserProfileScreen(username: name)),
              );
            }
          },
        ),
      ),
    );
  }

  /// 某条评论是否含有「发布者（帖子作者）的回复」。
  bool _authorRepliedTo(Comment c) =>
      c.replies.any((r) => r.name == _p.author);

  /// 顶部评论排序：发布者赞过 / 回复过的评论置顶；返回 _p.comments 原始索引，
  /// 保证回复 path 仍指向正确节点。
  List<int> _topOrder() {
    final eng = <int>[];
    final rest = <int>[];
    for (int i = 0; i < _p.comments.length; i++) {
      final c = _p.comments[i];
      if (c.authorLiked || _authorRepliedTo(c)) {
        eng.add(i);
      } else {
        rest.add(i);
      }
    }
    return [...eng, ...rest];
  }

  /// 小标签（置顶 / 作者赞过 等）。
  Widget _tag(String label, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label, style: TextStyle(fontSize: 10, color: fg)),
      );

  /// 发布者点赞 / 取消点赞某条评论（只记录发布者，用于「作者赞过」标注 + 置顶）。
  Future<void> _toggleCommentLike(Comment c) async {
    setState(() => c.authorLiked = !c.authorLiked);
    try {
      await DB.updatePost(_p);
      final fresh = await DB.postById(_p.id!, includeHidden: true);
      if (fresh != null && mounted) _p = fresh;
      if (mounted) setState(() {});
    } catch (e) {
      setState(() => c.authorLiked = !c.authorLiked); // 回滚
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t('操作失败')}：${e.toString()}')),
        );
      }
    }
  }

  /// 谁能删这条评论：发布者（帖子作者）/ 管理员可删任意评论；评论作者也能删自己的。
  bool _canDeleteComment(Comment c) => _canDelete || c.name == _me;

  Widget _comment(Comment c, List<int> path) {
    final topLevel = path.isEmpty;
    final isOp = c.name == _p.author;
    final opReplied = _authorRepliedTo(c);
    final pinned = topLevel && (c.authorLiked || opReplied);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => UserProfileScreen(username: c.name)),
              ),
              child: userAvatarByName(c.name, radius: 12),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 13, color: textColor),
                      children: [
                        TextSpan(
                            text: c.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, color: primary)),
                        if (isOp) ...[
                          const WidgetSpan(child: SizedBox(width: 4)),
                          WidgetSpan(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('作者',
                                  style: TextStyle(
                                      fontSize: 9, color: Colors.white)),
                            ),
                          ),
                        ],
                        const WidgetSpan(child: SizedBox(width: 4)),
                        WidgetSpan(child: _commentContent(c)),
                        if (c.uncertain)
                          TextSpan(
                            text: '  [${t('待审核')}]',
                            style: const TextStyle(
                                fontSize: 10, color: Colors.orange),
                          ),
                      ],
                    ),
                  ),
                  Wrap(
                    spacing: 14,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => _setReply(path, c.name),
                        child: Text(t('回复'),
                            style: const TextStyle(
                                color: primary, fontSize: 11)),
                      ),
                      if (pinned)
                        _tag(t('置顶'), Colors.grey.shade700,
                            Colors.grey.shade200),
                      if (c.authorLiked)
                        _tag('❤ ${t('作者赞过')}', likeColor,
                            likeColor.withOpacity(0.12)),
                      if (_isAuthor)
                        GestureDetector(
                          onTap: () => _toggleCommentLike(c),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                  c.authorLiked
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  size: 13,
                                  color: c.authorLiked
                                      ? likeColor
                                      : subColor),
                              const SizedBox(width: 3),
                              Text(t('赞'),
                                  style: TextStyle(
                                      fontSize: 11, color: subColor)),
                            ],
                          ),
                        ),
                      if (_canDeleteComment(c))
                        GestureDetector(
                          onTap: () => _deleteComment(c),
                          child: Text(t('删除'),
                              style: const TextStyle(
                                  color: Colors.redAccent, fontSize: 11)),
                        )
                      else if (_me != null)
                        GestureDetector(
                          onTap: () => _reportComment(c),
                          child: Text(t('举报'),
                              style: const TextStyle(
                                  color: subColor, fontSize: 11)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        if (c.replies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 20, top: 6),
            child: Container(
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(color: Color(0xFFECEEF2), width: 2),
                ),
              ),
              padding: const EdgeInsets.only(left: 8),
              child: Column(
                children: c.replies.asMap().entries.map((e) {
                  return _comment(e.value, [...path, e.key]);
                }).toList(),
              ),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = parseColor(_p.color);
    final dark = Color.fromARGB(
      255,
      (c.red - 40).clamp(0, 255),
      (c.green - 40).clamp(0, 255),
      (c.blue - 40).clamp(0, 255),
    );
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () async {
            await _save();
            if (mounted) Navigator.pop(context, true);
          },
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(t('详情')),
        actions: [
          if (_canDelete)
            IconButton(
              onPressed: _deletePost,
              icon: const Icon(Icons.delete_outline),
              tooltip: t('删除'),
            ),
          IconButton(
            onPressed: _reportPost,
            icon: const Icon(Icons.flag_outlined),
            tooltip: t('举报'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  if (_p.images.isNotEmpty)
                    AspectRatio(
                      // 3:4 竖图比例（小红书风），比原先固定 240px 裁切少得多
                      aspectRatio: 3 / 4,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image(
                            image: adaptiveImage(_p.images.first),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: bgColor,
                              child: const Icon(Icons.broken_image,
                                  size: 40, color: subColor),
                            ),
                          ),
                          if (_p.sold) _soldOverlay(),
                        ],
                      ),
                    )
                  else
                    Stack(
                      children: [
                        Container(
                          height: 168,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [c, dark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.22),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(_p.board,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(height: 10),
                              Expanded(
                                child: Text(_p.title,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        height: 1.3)),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(_boardEmojiOf(_p.board),
                                    style: TextStyle(
                                        fontSize: 44,
                                        color: Colors.white
                                            .withOpacity(0.22))),
                              ),
                            ],
                          ),
                        ),
                        if (_p.sold) _soldOverlay(),
                      ],
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => UserProfileScreen(
                                        username: _p.author)),
                              ),
                              child: userAvatarByName(_p.author, radius: 20),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => UserProfileScreen(
                                          username: _p.author)),
                                ),
                                child: Text(_p.author,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: textColor)),
                              ),
                            ),
                            if (_p.uncertain)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(t('待审核'),
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.orange)),
                              ),
                          ],
                        ),
                        if (_isAuthor && _p.board == '黑市') ...[
                          const SizedBox(height: 10),
                          _soldAction(),
                        ],
                        if (_p.images.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(_p.title,
                              style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  height: 1.4)),
                        ],
                        const SizedBox(height: 6),
                        Text('${_p.board} · ${t('浏览')} ${_p.views} · ${_p.time}',
                            style: const TextStyle(
                                color: subColor, fontSize: 12)),
                        const SizedBox(height: 12),
                        if (_p.body.isNotEmpty)
                          Text(_p.body,
                              style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.7,
                                  color: textColor)),
                        if (_p.images.length > 1) ...[
                          const SizedBox(height: 12),
                          GridView.count(
                            crossAxisCount: 3,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 6,
                            children: _p.images.skip(1).map((img) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image(image: adaptiveImage(img),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.broken_image,
                                            color: subColor)),
                              );
                            }).toList(),
                          ),
                        ],
                        if (_p.videos.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ..._p.videos.map((v) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: PostVideoPlayer(url: v),
                              )),
                        ],
                        const SizedBox(height: 14),
                        Text('${t('评论')} ${_count(_p.comments)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 4),
                        ..._topOrder().map((i) {
                          return _comment(_p.comments[i], [i]);
                        }).toList(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_replyName != null)
            Container(
              color: bgColor,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                children: [
                  Text('回复 @$_replyName',
                      style: const TextStyle(fontSize: 12, color: primary)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() {
                      _replyPath = null;
                      _replyName = null;
                    }),
                    child:
                        const Text('取消', style: TextStyle(fontSize: 12, color: subColor)),
                  ),
                ],
              ),
            ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  /// 底部栏：模仿小红书 —— 左侧评论输入框，右侧 ❤️收藏↗ 操作，下方展开表情/相册/@ 工具。
  Widget _buildBottomBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFECEEF2))),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _focus,
                    maxLines: 3,
                    minLines: 1,
                    decoration: InputDecoration.collapsed(
                      hintText: _replyName == null
                          ? '${t('说点什么')}…'
                          : '${t('回复')} @$_replyName',
                      hintStyle: const TextStyle(fontSize: 13, color: subColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _iconBtn(Icons.favorite, _p.liked ? likeColor : subColor,
                  () => _toggleLike()),
              _iconBtn(Icons.star, _p.collected ? likeColor : subColor,
                  () => _toggleCollect()),
              _iconBtn(Icons.share, subColor, _shareSnackbar),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: _sendComment,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text('发送',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _tool(Icons.emoji_emotions_outlined,
                  () => showEmojiSheet(context, (e) => _ctrl.text += e)),
              _tool(Icons.image_outlined, () async {
                final p = await pickAndSaveImage(ImageSource.gallery,
                    'post_${DateTime.now().microsecondsSinceEpoch}');
                if (p != null) _send(imagePath: p);
              }),
              _tool(Icons.face_outlined,
                  () => showStickerSheet(context, (s) => _send(sticker: s))),
              _tool(Icons.alternate_email,
                  () => showMentionSheet(context, _friends, _insertMention)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Icon(icon, size: 24, color: color),
        ),
      );

  Widget _tool(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Icon(icon, size: 22, color: subColor),
        ),
      );

  void _insertMention(String name) {
    final txt = _ctrl.text;
    final sel = _ctrl.selection.baseOffset;
    final pos = sel < 0 ? txt.length : sel;
    _ctrl.text = '${txt.substring(0, pos)}@$name ${txt.substring(pos)}';
    _ctrl.selection = TextSelection.collapsed(offset: pos + name.length + 2);
    _focus.requestFocus();
  }

  void _shareSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t('已复制分享链接（演示）'))),
    );
  }

  Future<void> _sendComment() async {
    final txt = _ctrl.text.trim();
    if (txt.isEmpty) return;
    await _send(text: txt);
    _ctrl.clear();
  }
}

/// 帖子里的视频播放器：初始化完成后内联播放，点击中央按钮暂停/播放。
class PostVideoPlayer extends StatefulWidget {
  final String url;
  const PostVideoPlayer({super.key, required this.url});
  @override
  State<PostVideoPlayer> createState() => _PostVideoPlayerState();
}

class _PostVideoPlayerState extends State<PostVideoPlayer> {
  late VideoPlayerController _c;
  bool _ready = false;
  bool _playing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _c = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) setState(() => _ready = true);
      }).catchError((e) {
        if (mounted) setState(() => _error = e.toString());
      });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Container(
        height: 220,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off, size: 36, color: Colors.grey),
            const SizedBox(height: 8),
            const Text('视频无法在应用内播放', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 6),
            SelectableText(widget.url,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 6),
            const Text('可复制上方链接，在浏览器新标签打开观看',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      );
    }
    if (!_ready) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return AspectRatio(
      aspectRatio: _c.value.aspectRatio,
      child: Stack(
        alignment: Alignment.center,
        children: [
          VideoPlayer(_c),
          GestureDetector(
            onTap: () {
              if (_playing) {
                _c.pause();
              } else {
                _c.play();
              }
              setState(() => _playing = !_playing);
            },
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black38,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(12),
              child: Icon(
                _playing ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

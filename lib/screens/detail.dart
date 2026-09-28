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
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _p = widget.post;
    if (_p.id != null) {
      DB.getCurrentUser().then((me) {
        if (me != null) DB.addHistory(_p.id!);
      });
    }
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
    _targetReplies().add(cm);
    if (uncertain) {
      await DB.addReport(Report(
        type: 'comment',
        targetId: _p.id!,
        commentId: cm.id,
        reporter: 'bot',
        source: 'bot',
        reason: t('边界词触发，已放行但待人工复核'),
      ));
    }
    _replyPath = null;
    _replyName = null;
    await DB.updatePost(_p);
    setState(() {});
  }

  void _setReply(List<int> path, String name) {
    setState(() {
      _replyPath = path;
      _replyName = name;
    });
  }

  Future<void> _save() async => DB.updatePost(_p);

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

  Widget _comment(Comment c, List<int> path) {
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
                        TextSpan(text: '  '),
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
                  GestureDetector(
                    onTap: () => _setReply(path, c.name),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(t('回复'),
                          style: const TextStyle(
                              color: primary, fontSize: 11)),
                    ),
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
                    SizedBox(
                      width: double.infinity,
                      height: 240,
                      child: Image(
                        image: adaptiveImage(_p.images.first),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: bgColor,
                          child: const Icon(Icons.broken_image,
                              size: 40, color: subColor),
                        ),
                      ),
                    )
                  else
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
                                    color: Colors.white.withOpacity(0.22))),
                          ),
                        ],
                      ),
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
                        const SizedBox(height: 14),
                        Text('${t('评论')} ${_count(_p.comments)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 4),
                        ..._p.comments.asMap().entries.map((e) {
                          return _comment(e.value, [e.key]);
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

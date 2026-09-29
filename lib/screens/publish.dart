import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models.dart';
import '../db.dart';
import '../moderation.dart';
import '../ui.dart';
import '../lang.dart';
import '../widgets/compose.dart';

const primary = Color(0xFF3B6FE0);
const subColor = Color(0xFF8A90A2);
const bgColor = Color(0xFFF4F5F7);

class PublishScreen extends StatefulWidget {
  final String? defaultBoard;
  const PublishScreen({super.key, this.defaultBoard});

  @override
  State<PublishScreen> createState() => _PublishScreenState();
}

class _PublishScreenState extends State<PublishScreen> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  late String _board;
  final List<String> _imgPaths = [];
  bool _publishing = false; // 防止重复点击；发布中显示转圈
  final _boards = const ['校园圈', '黑市', '拼车', '招募', '招领', '问答'];
  static const _colors = {
    '校园圈': '#3B6FE0',
    '黑市': '#3B6FE0',
    '拼车': '#2FB573',
    '招募': '#F25C7E',
    '招领': '#7D5FFF',
    '问答': '#F5A623',
  };

  @override
  void initState() {
    super.initState();
    _board = (widget.defaultBoard != null &&
            _boards.contains(widget.defaultBoard))
        ? widget.defaultBoard!
        : '校园圈';
  }

  Future<void> _addImg() async {
    if (_imgPaths.length >= 9) return;
    final p = await pickAndSaveImage(
        ImageSource.gallery, 'post_${DateTime.now().microsecondsSinceEpoch}');
    if (p != null) setState(() => _imgPaths.add(p));
  }

  void _removeImg(int i) => setState(() => _imgPaths.removeAt(i));

  Future<void> _publish() async {
    if (_publishing) return; // 发布进行中，忽略重复点击
    final t = _title.text.trim();
    final c = _content.text.trim();
    if (t.isEmpty && c.isEmpty && _imgPaths.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('写点什么再发布吧')));
      return;
    }
    final review = Moderator.checkPost(title: t, body: c);
    if (review.status == ModStatus.blocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(review.reason ?? '内容未通过审核')),
      );
      return;
    }
    setState(() => _publishing = true);
    try {
      final me = await DB.getCurrentUser() ?? '我';
      final uncertain = review.status == ModStatus.uncertain;
      final post = Post(
        board: _board,
        title: t.isEmpty ? '(无标题)' : t,
        body: c,
        imageCaption:
            _imgPaths.isEmpty ? '我的发布封面' : '图片 ${_imgPaths.length} 张',
        color: _colors[_board]!,
        author: me,
        views: 0,
        likes: 0,
        comments: const [],
        uncertain: uncertain,
        images: List.from(_imgPaths),
      );
      await DB.insertPost(post);
      if (uncertain && post.id != null) {
        try {
          await DB.addReport(Report(
            type: 'post',
            targetId: post.id!,
            reporter: 'bot',
            source: 'bot',
            reason: '边界词触发，已放行但待人工复核',
          ));
        } catch (_) {// 举报失败不影响发布
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('发布成功！已出现在「校园圈」')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      // 网络失败/后端报错时给出明确反馈，而不是毫无反应
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发布失败，请检查网络后重试')),
        );
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back)),
        title: const Text('发布'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
              children: [
                ..._imgPaths.asMap().entries.map((e) => Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            image: DecorationImage(
                              image: adaptiveImage(e.value),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removeImg(e.key),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.close,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    )),
                if (_imgPaths.length < 9)
                  GestureDetector(
                    onTap: _addImg,
                    child: Container(
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFECEEF2),
                          width: 1.5,
                        ),
                      ),
                      child: const Center(
                        child: Text('＋',
                            style: TextStyle(color: subColor, fontSize: 24)),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                hintText: '填个标题，更容易被看到',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: primary),
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _content,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: '分享点什么… 价格、成色、地点、联系方式都可以写',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: primary),
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _tool(Icons.emoji_emotions_outlined, t('表情'),
                    () => showEmojiSheet(context, (e) => _content.text += e)),
                _tool(Icons.face_outlined, t('表情包'),
                    () => showStickerSheet(context, (s) => _content.text += s)),
                _tool(Icons.alternate_email, t('好友'),
                    () async {
                      final me = await DB.getCurrentUser() ?? '';
                      final friends = await DB.friendsOf(me);
                      showMentionSheet(context, friends, (n) {
                        final t0 = _content.text;
                        _content.text = '$t0@$n ';
                      });
                    }),
              ],
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('选择板块',
                  style: TextStyle(color: subColor, fontSize: 13)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _boards.map((n) {
                final on = n == _board;
                return GestureDetector(
                  onTap: () => setState(() => _board = n),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 13, vertical: 7),
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
              }).toList(),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _publishing ? null : _publish,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _publishing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: Colors.white),
                      )
                    : const Text('发布',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tool(IconData icon, String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 14),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: subColor),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 12, color: subColor)),
            ],
          ),
        ),
      );
}

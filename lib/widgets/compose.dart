import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../ui.dart';

const primary = Color(0xFF3B6FE0);
const subColor = Color(0xFF8A90A2);
const bgColor = Color(0xFFF4F5F7);
const textColor = Color(0xFF1F2330);

/// 选图并上传到 Supabase Storage 的 media 桶，返回公有 URL；取消或失败返回 null。
/// 同时兼容 Android（本地文件）与 Web（浏览器内选图），返回的都是可跨端访问的 URL。
Future<String?> pickAndSaveImage(ImageSource source, String name) async {
  try {
    final x = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (x == null) return null;
    final bytes = await x.readAsBytes();
    final ext =
        x.name.contains('.') ? x.name.split('.').last.toLowerCase() : 'jpg';
    final path = '$name.$ext';
    await Supabase.instance.client.storage.from('media').uploadBinary(
          path,
          bytes,
          fileOptions:
              FileOptions(upsert: true, contentType: 'image/$ext'),
        );
    return Supabase.instance.client.storage.from('media').getPublicUrl(path);
  } catch (_) {
    return null;
  }
}

/// emoji 选择面板
void showEmojiSheet(BuildContext context, void Function(String) onPick) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => Container(
      height: 240,
      padding: const EdgeInsets.all(12),
      child: GridView.count(
        crossAxisCount: 8,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        children: chatEmojis
            .map((e) => InkWell(
                  onTap: () {
                    onPick(e);
                    Navigator.pop(context);
                  },
                  child: Center(
                      child: Text(e, style: const TextStyle(fontSize: 24))),
                ))
            .toList(),
      ),
    ),
  );
}

/// 表情包面板（大号 emoji 充当；点击即作为一条 sticker 消息发出）
void showStickerSheet(BuildContext context, void Function(String) onPick) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => Container(
      height: 240,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text('表情包',
                style: TextStyle(fontSize: 13, color: subColor)),
          ),
          Expanded(
            child: GridView.count(
              crossAxisCount: 5,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: stickers
                  .map((e) => InkWell(
                        onTap: () {
                          onPick(e);
                          Navigator.pop(context);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(e, style: const TextStyle(fontSize: 34)),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    ),
  );
}

/// @好友 选择面板：列出好友，点击插入 "@用户名 "
void showMentionSheet(BuildContext context, List<String> friends,
    void Function(String) onPick) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => Container(
      height: 300,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text('@好友', style: TextStyle(fontSize: 13, color: subColor)),
          ),
          Expanded(
            child: friends.isEmpty
                ? const Center(
                    child: Text('还没有好友，去加几个吧',
                        style: TextStyle(color: subColor, fontSize: 13)))
                : ListView.separated(
                    itemCount: friends.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Color(0xFFECEEF2)),
                    itemBuilder: (_, i) => ListTile(
                      dense: true,
                      title: Text(friends[i],
                          style: const TextStyle(fontSize: 14)),
                      onTap: () {
                        onPick(friends[i]);
                        Navigator.pop(context);
                      },
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
}

/// 通用输入条：文本 + emoji + 表情包 + 本地相册 + @好友。
/// 发送时根据内容类型回调：纯文本 text；图片 imagePath；表情包 sticker。
class ComposeBar extends StatefulWidget {
  final String hint;
  final List<String> friends;
  final bool allowImage;
  final bool allowSticker;
  final void Function({String? text, String? imagePath, String? sticker})
      onSend;

  const ComposeBar({
    super.key,
    required this.hint,
    this.friends = const [],
    this.allowImage = true,
    this.allowSticker = true,
    required this.onSend,
  });

  @override
  State<ComposeBar> createState() => _ComposeBarState();
}

class _ComposeBarState extends State<ComposeBar> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  void _insertMention(String name) {
    final t = _ctrl.text;
    final sel = _ctrl.selection.baseOffset;
    final pos = sel < 0 ? t.length : sel;
    final before = t.substring(0, pos);
    final after = t.substring(pos);
    _ctrl.text = '$before@$name $after';
    final np = (before + '@$name ').length;
    _ctrl.selection = TextSelection.collapsed(offset: np);
    _focus.requestFocus();
  }

  void _send() {
    final txt = _ctrl.text.trim();
    if (txt.isEmpty) return;
    widget.onSend(text: txt);
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFECEEF2))),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Row(
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
                  hintText: widget.hint,
                  hintStyle: const TextStyle(fontSize: 13, color: subColor),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          _icon(Icons.emoji_emotions_outlined, () =>
              showEmojiSheet(context, (e) => _ctrl.text += e)),
          if (widget.allowImage)
            _icon(Icons.image_outlined, () async {
              final p = await pickAndSaveImage(
                  ImageSource.gallery, 'chat_${DateTime.now().microsecondsSinceEpoch}');
              if (p != null) widget.onSend(imagePath: p);
            }),
          if (widget.allowSticker)
            _icon(Icons.face_outlined, () =>
                showStickerSheet(context, (s) => widget.onSend(sticker: s))),
          _icon(Icons.alternate_email, () =>
              showMentionSheet(context, widget.friends, _insertMention)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _send,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
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
    );
  }

  Widget _icon(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
          child: Icon(icon, size: 22, color: subColor),
        ),
      );
}

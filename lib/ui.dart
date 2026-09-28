import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'models.dart';
import 'db.dart';

/// 头像底色候选（与品牌色呼应）
const List<String> avatarColors = [
  '#3B6FE0', '#F25C7E', '#2FB573', '#FF5A3C', '#7D5FFF',
  '#19B5C4', '#F2A93B', '#5C7BF2', '#E0518A', '#3A2E7A',
];

/// 头像 emoji 候选
const List<String> avatarEmojis = [
  '🐱', '🐶', '🦊', '🐼', '🐰', '🐯', '🦁', '🐸',
  '🐵', '🐧', '🦄', '🌟', '🌙', '🔥', '🌈', '🍀',
  '🎓', '📚', '⚽', '🎮', '🍜', '☕', '🌻', '💡',
];

/// 聊天 / 评论可发的 emoji（比头像候选更丰富）
const List<String> chatEmojis = [
  '😀', '😂', '🤣', '😊', '😍', '😘', '😜', '🤔',
  '😎', '😭', '😡', '👍', '👎', '👏', '🙏', '💪',
  '❤️', '💔', '🔥', '✨', '🎉', '🌹', '💡', '⚡',
  '🌙', '🌟', '🍀', '🐱', '🐶', '🦊', '🐼', '🐰',
  '🍜', '☕', '🍔', '🎮', '📚', '🎓', '🚀', '🎯',
];

/// 表情包（本地用大号 emoji 充当；上服务器后可替换为图片资源）
const List<String> stickers = [
  '😂', '🤣', '😍', '😎', '🥺', '😭', '👍', '🙏',
  '💪', '🔥', '🎉', '❤️', '💔', '😱', '🤔', '😴',
];

Color parseColor(String hex) {
  try {
    return Color(int.parse(hex.replaceFirst('#', '0xFF')));
  } catch (_) {
    return const Color(0xFF3B6FE0);
  }
}

/// 图片源自适应：http(s) 链接（Supabase Storage 返回的 URL）走网络图，
/// 其余按本地文件路径处理（兼容旧数据 / Android 本地图）。
ImageProvider adaptiveImage(String src) =>
    src.startsWith('http') ? NetworkImage(src) : FileImage(File(src));

Widget buildAvatar({
  required String colorHex,
  String? emoji,
  String? initial,
  String? imagePath,
  double radius = 18,
}) {
  if (imagePath != null && imagePath.isNotEmpty) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: parseColor(colorHex),
      backgroundImage: adaptiveImage(imagePath),
      onBackgroundImageError: (_, __) {},
      child: const SizedBox.shrink(),
    );
  }
  return CircleAvatar(
    radius: radius,
    backgroundColor: parseColor(colorHex),
    child: (emoji != null && emoji.isNotEmpty)
        ? Text(emoji, style: TextStyle(fontSize: radius * 0.95))
        : Text(
            initial ?? '',
            style: TextStyle(
              fontSize: radius * 0.8,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
  );
}

Widget userAvatar(User? u, {double radius = 18}) {
  return buildAvatar(
    colorHex: u?.avatarColor ?? '#3B6FE0',
    emoji: u?.avatarEmoji,
    initial: (u?.username.isNotEmpty == true) ? u!.username[0] : '',
    imagePath: u?.avatarPath,
    radius: radius,
  );
}

/// 按用户名异步取头像（getUser 是异步的，build 里直接传 User? 会编译/运行出错）。
/// 用法：把原本的 `userAvatar(DB.getUser(name), radius: r)` 换成 `userAvatarByName(name, radius: r)`。
Widget userAvatarByName(String? username, {double radius = 18}) {
  if (username == null) return userAvatar(null, radius: radius);
  return FutureBuilder<User?>(
    future: DB.getUser(username),
    builder: (_, s) => userAvatar(s.data, radius: radius),
  );
}

/// 把文本里的 @用户名 高亮（@ 后连续非空白字符视为被 @ 的人）。
/// 命中好友名或任意 @词都会着色；onMention 可选，点击 @词回调。
List<TextSpan> mentionSpans(
  String text, {
  TextStyle? base,
  TextStyle? mentionStyle,
  void Function(String)? onMention,
}) {
  final baseStyle = base ??
      const TextStyle(fontSize: 14, color: Color(0xFF1F2330), height: 1.5);
  final mStyle = mentionStyle ??
      const TextStyle(
          fontSize: 14, color: Color(0xFF3B6FE0), fontWeight: FontWeight.w600);
  final reg = RegExp(r'@([^\s@]+)');
  final spans = <TextSpan>[];
  int last = 0;
  for (final m in reg.allMatches(text)) {
    if (m.start > last) {
      spans.add(TextSpan(text: text.substring(last, m.start), style: baseStyle));
    }
    final name = m.group(0)!; // 含 @
    spans.add(TextSpan(
      text: name,
      style: mStyle,
      recognizer: onMention != null
          ? (TapGestureRecognizer()..onTap = () => onMention(name.substring(1)))
          : null,
    ));
    last = m.end;
  }
  if (last < text.length) {
    spans.add(TextSpan(text: text.substring(last), style: baseStyle));
  }
  return spans;
}

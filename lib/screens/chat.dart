import 'package:flutter/material.dart';
import '../models.dart';
import '../db.dart';
import '../ui.dart';
import '../lang.dart';
import '../widgets/compose.dart';
import 'user_profile.dart';

const primary = Color(0xFF3B6FE0);
const subColor = Color(0xFF8A90A2);
const bgColor = Color(0xFFF4F5F7);
const textColor = Color(0xFF1F2330);

class ChatScreen extends StatefulWidget {
  final String peer;
  const ChatScreen({super.key, required this.peer});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<Message> _msgs = [];
  List<String> _friends = [];
  String _me = '';
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final me = await DB.getCurrentUser() ?? '';
    final msgs = await DB.messagesBetween(me, widget.peer);
    final friends = await DB.friendsOf(me);
    await DB.markRead(me, widget.peer);
    if (mounted) {
      setState(() {
        _me = me;
        _msgs = msgs;
      });
    }
    _friends = friends;
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send(
      {String? text, String? imagePath, String? sticker}) async {
    final me = await DB.getCurrentUser() ?? '';
    final now = TimeOfDay.now();
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final m = Message(
      from: me,
      to: widget.peer,
      text: text,
      imagePath: imagePath,
      sticker: sticker,
      time: time,
      read: false,
    );
    await DB.sendMessage(m);
    setState(() => _msgs.add(m));
    _scrollToEnd();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Row(
          children: [
            userAvatarByName(widget.peer, radius: 15),
            const SizedBox(width: 8),
            Text(widget.peer, style: const TextStyle(fontSize: 16)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => UserProfileScreen(username: widget.peer)),
            ),
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              children: _msgs.map(_bubble).toList(),
            ),
          ),
          ComposeBar(
            hint: '说点什么…',
            friends: _friends,
            onSend: ({text, imagePath, sticker}) =>
                _send(text: text, imagePath: imagePath, sticker: sticker),
          ),
        ],
      ),
    );
  }

  Widget _bubble(Message m) {
    final mine = m.from == _me;
    if (m.recalled) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text('${mine ? '你' : m.from} 撤回了一条消息',
              style: const TextStyle(fontSize: 11, color: subColor)),
        ),
      );
    }
    final align = mine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    return Column(
      crossAxisAlignment: align,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 5),
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72),
          padding: m.sticker != null
              ? const EdgeInsets.all(6)
              : const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: m.sticker != null
                ? Colors.transparent
                : (mine ? primary : Colors.white),
            borderRadius: BorderRadius.circular(14),
            border: (!mine && m.sticker == null)
                ? Border.all(color: const Color(0xFFECEEF2))
                : null,
          ),
          child: _content(m, mine),
        ),
      ],
    );
  }

  Widget _content(Message m, bool mine) {
    final txtColor = mine ? Colors.white : textColor;
    if (m.sticker != null) {
      return Text(m.sticker!, style: const TextStyle(fontSize: 48));
    }
    if (m.imagePath != null && m.imagePath!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image(image: adaptiveImage(m.imagePath!),
            width: 160, height: 160, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.broken_image, size: 48, color: subColor)),
      );
    }
    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 14, color: txtColor, height: 1.5),
        children: mentionSpans(
          m.text ?? '',
          base: TextStyle(fontSize: 14, color: txtColor, height: 1.5),
          mentionStyle: TextStyle(
            fontSize: 14,
            color: mine ? Colors.white : primary,
            fontWeight: FontWeight.w600,
          ),
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
}

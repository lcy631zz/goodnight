import 'package:flutter/material.dart';
import '../models.dart';
import '../db.dart';
import '../lang.dart';
import '../config/update_config.dart';

const primary = Color(0xFF3B6FE0);
const subColor = Color(0xFF8A90A2);
const textColor = Color(0xFF1F2330);

/// 用户反馈提交页：选类型 + 写描述，提交到 Supabase 的 feedback 表。
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  String _type = 'bug';
  final _ctrl = TextEditingController();
  bool _sending = false;

  final List<_FbType> _types = const [
    _FbType('bug', '缺陷', '🐞'),
    _FbType('suggestion', '建议', '💡'),
    _FbType('other', '其他', '💬'),
  ];

  Future<void> _submit() async {
    final content = _ctrl.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t('请先填写内容'))));
      return;
    }
    setState(() => _sending = true);
    final me = await DB.getCurrentUser();
    final f = AppFeedback(
      type: _type,
      content: content,
      username: me ?? '匿名用户',
      appVersion: kCurrentVersion,
    );
    try {
      await DB.submitFeedback(f);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t('已提交，感谢反馈！'))));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t('提交失败，请检查网络'))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('意见反馈'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(t('反馈类型'),
              style: const TextStyle(
                  fontSize: 14, color: subColor, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
            segments: _types
                .map((e) =>
                    ButtonSegment(value: e.key, label: Text('${e.emoji} ${e.label}')))
                .toList(),
          ),
          const SizedBox(height: 16),
          Text(t('详细描述'),
              style: const TextStyle(
                  fontSize: 14, color: subColor, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl,
            maxLines: 8,
            decoration: InputDecoration(
              hintText: t('请描述你遇到的问题或建议…'),
              hintStyle: const TextStyle(color: subColor),
              filled: true,
              fillColor: const Color(0xFFF4F5F7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 8),
          Text('App 版本 v$kCurrentVersion · 提交即视为同意我们用于改进产品',
              style: const TextStyle(fontSize: 11, color: subColor)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: _sending ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(_sending ? t('提交中…') : t('提交反馈'),
                  style: const TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

class _FbType {
  final String key;
  final String label;
  final String emoji;
  const _FbType(this.key, this.label, this.emoji);
}

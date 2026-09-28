import 'package:flutter/material.dart';
import '../models.dart';
import '../db.dart';
import '../lang.dart';

const primary = Color(0xFF3B6FE0);
const subColor = Color(0xFF8A90A2);
const textColor = Color(0xFF1F2330);

/// 管理员查看用户反馈列表（仅由 AdminScreen 进入；开发者据此改进 App）。
class FeedbackAdminScreen extends StatefulWidget {
  const FeedbackAdminScreen({super.key});

  @override
  State<FeedbackAdminScreen> createState() => _FeedbackAdminScreenState();
}

class _FeedbackAdminScreenState extends State<FeedbackAdminScreen> {
  List<AppFeedback> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await DB.allFeedback();
      if (mounted) {
        setState(() {
          _items = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  final Map<String, String> _labels = {
    'bug': '缺陷',
    'suggestion': '建议',
    'other': '其他',
  };

  Future<void> _toggle(AppFeedback f) async {
    if (f.id == null) return;
    await DB.resolveFeedback(f.id!, f.status != 'handled');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(t(f.status == 'handled' ? '已重新打开' : '已标记为处理'))));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('用户反馈'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Text(t('暂无反馈'),
                      style: const TextStyle(color: subColor)))
              : ListView.separated(
                  padding: const EdgeInsets.all(14),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _card(_items[i]),
                ),
    );
  }

  Widget _card(AppFeedback f) {
    final handled = f.status == 'handled';
    final label = _labels[f.type] ?? '其他';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: f.type == 'bug'
                      ? Colors.red.shade50
                      : const Color(0xFFE8F0FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(label, style: const TextStyle(fontSize: 11)),
              ),
              const SizedBox(width: 8),
              if (handled)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('已处理',
                      style: TextStyle(fontSize: 11, color: Colors.green)),
                ),
              const Spacer(),
              Text('v${f.appVersion}',
                  style: const TextStyle(fontSize: 11, color: subColor)),
            ],
          ),
          const SizedBox(height: 8),
          Text(f.content.isEmpty ? t('（内容为空）') : f.content,
              style: const TextStyle(fontSize: 14, color: textColor)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('${t('提交人')}: ${f.username}',
                  style: const TextStyle(fontSize: 11, color: subColor)),
              const Spacer(),
              if (f.createdAt != null)
                Expanded(
                  child: Text(f.createdAt!,
                      style: const TextStyle(fontSize: 11, color: subColor),
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _toggle(f),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: handled ? primary : Colors.green),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(handled ? t('重新打开') : t('标为已处理'),
                  style: TextStyle(color: handled ? primary : Colors.green)),
            ),
          ),
        ],
      ),
    );
  }
}

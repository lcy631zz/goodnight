import 'package:flutter/material.dart';
import '../models.dart';
import '../db.dart';
import '../lang.dart';

const primary = Color(0xFF3B6FE0);
const subColor = Color(0xFF8A90A2);
const textColor = Color(0xFF1F2330);

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  List<Report> _items = [];
  final Map<int, String> _snippet = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final reports = await DB.pendingReports();
    final map = <int, String>{};
    for (final r in reports) {
      final p = await DB.postById(r.targetId, includeHidden: true);
      if (p == null) {
        map[r.id] = t('（原内容已不存在）');
        continue;
      }
      if (r.type == 'post') {
        map[r.id] = '${p.title}\n${p.body}';
      } else if (r.commentId != null) {
        map[r.id] = _commentText(p, r.commentId!) ?? '';
      }
    }
    if (mounted) setState(() => _items = reports);
    _snippet.clear();
    _snippet.addAll(map);
  }

  String? _commentText(Post p, int cid) {
    String? walk(List<Comment> list) {
      for (final c in list) {
        if (c.id == cid) return c.text;
        final r = walk(c.replies);
        if (r != null) return r;
      }
      return null;
    }

    return walk(p.comments);
  }

  Future<void> _resolve(Report r, bool approve) async {
    final me = await DB.getCurrentUser() ?? 'admin';
    await DB.resolveReport(r.id, approve, me);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(approve ? t('已通过') : t('已删除内容'))));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('审核中心'))),
      body: _items.isEmpty
          ? Center(
              child: Text(t('暂无待审核内容'),
                  style: const TextStyle(color: subColor)),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(14),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final r = _items[i];
                final isPost = r.type == 'post';
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 8,
                          offset: Offset(0, 2)),
                    ],
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: r.source == 'bot'
                                  ? Colors.orange.shade100
                                  : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isPost ? t('帖子') : t('评论'),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: r.source == 'bot'
                                  ? Colors.orange.shade100
                                  : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              r.source == 'bot' ? t('机器人标记') : t('用户举报'),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            r.reporter == 'bot'
                                ? 'bot'
                                : '${t('举报人')}: ${r.reporter}',
                            style: const TextStyle(
                                fontSize: 11, color: subColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (r.reason != null)
                        Text('${t('原因')}: ${r.reason}',
                            style: const TextStyle(
                                fontSize: 12, color: subColor)),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F5F7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          (_snippet[r.id] ?? '').isEmpty
                              ? t('（内容为空）')
                              : (_snippet[r.id]!),
                          maxLines: 6,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: textColor),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _resolve(r, true),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: primary),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Text(t('通过'),
                                  style: const TextStyle(color: primary)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _resolve(r, false),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Text(t('删除'),
                                  style: const TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

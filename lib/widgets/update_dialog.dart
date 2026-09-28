import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../config/update_config.dart';
import '../update_service.dart';

const _primary = Color(0xFF3B6FE0);
const _subColor = Color(0xFF8A90A2);

/// 小红书风格的更新弹窗。forceUpdate=true 时不可关闭，必须先更新。
Future<void> showUpdateDialog(BuildContext context, UpdateCheckResult res) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isDismissible: !res.forceUpdate,
    enableDrag: !res.forceUpdate,
    builder: (_) => _UpdateSheet(info: res.info, force: res.forceUpdate),
  );
}

class _UpdateSheet extends StatefulWidget {
  final UpdateInfo info;
  final bool force;
  const _UpdateSheet({required this.info, required this.force});

  @override
  State<_UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends State<_UpdateSheet> {
  int _percent = 0;
  bool _busy = false;
  String _err = '';

  Future<void> _doUpdate() async {
    if (_busy || kIsWeb) return;
    setState(() {
      _busy = true;
      _err = '';
    });
    await startUpdate(
      widget.info.downloadUrl,
      onProgress: (p) {
        if (mounted) setState(() => _percent = p);
      },
      onError: (e) {
        if (mounted) setState(() => _err = e);
      },
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final notes = widget.info.releaseNotes ?? '';
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 22,
        bottom: 20 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.system_update_alt,
                    color: _primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('发现新版本 v${widget.info.latestVersion}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('当前版本 v$kCurrentVersion',
              style: const TextStyle(fontSize: 12, color: _subColor)),
          const SizedBox(height: 14),
          if (notes.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F5F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(notes,
                  style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1F2330),
                      height: 1.5)),
            ),
          const SizedBox(height: 16),
          if (_busy) ...[
            LinearProgressIndicator(
              value: _percent / 100,
              backgroundColor: const Color(0xFFECEEF2),
              valueColor: const AlwaysStoppedAnimation(_primary),
              minHeight: 6,
            ),
            const SizedBox(height: 8),
            Text('正在下载… $_percent%',
                style: const TextStyle(fontSize: 12, color: _subColor)),
          ],
          if (_err.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_err,
                  style: const TextStyle(fontSize: 12, color: Colors.red)),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (!widget.force)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFECEEF2)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('稍后',
                        style: TextStyle(color: _subColor)),
                  ),
                ),
              if (!widget.force) const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _busy ? null : _doUpdate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(_busy ? '下载中…' : '立即更新',
                      style: const TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../models.dart';
import '../db.dart';
import '../ui.dart';
import '../lang.dart';

const primary = Color(0xFF3B6FE0);
const subColor = Color(0xFF8A90A2);
const textColor = Color(0xFF1F2330);

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  User? _u;
  late TextEditingController _bio;
  late TextEditingController _region;

  @override
  void initState() {
    super.initState();
    _bio = TextEditingController();
    _region = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    final u = await DB.currentUserModel();
    if (u == null) return;
    _bio.text = u.bio ?? '';
    _region.text = u.region ?? '';
    setState(() => _u = u);
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final ext = picked.name.contains('.')
        ? picked.name.split('.').last.toLowerCase()
        : 'jpg';
    final path = 'avatars/${_u!.username}.$ext';
    await Supabase.instance.client.storage.from('media').uploadBinary(
          path,
          bytes,
          fileOptions:
              FileOptions(upsert: true, contentType: 'image/$ext'),
        );
    final url =
        Supabase.instance.client.storage.from('media').getPublicUrl(path);
    setState(() => _u!.avatarPath = url);
  }

  Future<void> _save() async {
    if (_u == null) return;
    _u!.bio = _bio.text.trim().isEmpty ? null : _bio.text.trim();
    _u!.region = _region.text.trim().isEmpty ? null : _region.text.trim();
    await DB.updateUser(_u!);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t('保存成功'))));
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_u == null) {
      return Scaffold(
        appBar: AppBar(title: Text(t('编辑资料'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(t('编辑资料')),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(t('保存'),
                style: const TextStyle(color: primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(child: userAvatar(_u, radius: 40)),
          const SizedBox(height: 10),
          Center(
            child: OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo_library_outlined, size: 16),
              label: Text(t('从相册选择')),
              style: OutlinedButton.styleFrom(
                foregroundColor: primary,
                side: const BorderSide(color: primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(t('更换头像'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: avatarEmojis.map((e) {
              final on = _u!.avatarEmoji == e;
              return GestureDetector(
                onTap: () => setState(() {
                  _u!.avatarEmoji = e;
                  _u!.avatarPath = null; // 选 emoji 时清掉导入图
                }),
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: on ? primary : Colors.transparent, width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(e, style: const TextStyle(fontSize: 22)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text(t('头像底色'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: avatarColors.map((hex) {
              final on = _u!.avatarColor == hex;
              return GestureDetector(
                onTap: () => setState(() => _u!.avatarColor = hex),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: parseColor(hex),
                    border: Border.all(
                        color: on ? textColor : Colors.transparent, width: 2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          _field(_bio, t('简介（一句话介绍自己）'), 3),
          const SizedBox(height: 12),
          _field(_region, t('自选地区（如：北京 / 上海）'), 1),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(t('性别 / 级 / 专业为学校导入的学生信息，暂不支持自行修改'),
                style: const TextStyle(fontSize: 12, color: subColor)),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, int lines) {
    return TextField(
      controller: c,
      maxLines: lines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: subColor),
        filled: true,
        fillColor: const Color(0xFFF4F5F7),
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

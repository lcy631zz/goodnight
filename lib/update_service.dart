import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'config/update_config.dart';

/// 远程 version_check.json 解析结果
class UpdateInfo {
  final String latestVersion;
  final String? minRequiredVersion;
  final String downloadUrl;
  final String? releaseNotes;
  final bool forceUpdate;

  UpdateInfo({
    required this.latestVersion,
    this.minRequiredVersion,
    required this.downloadUrl,
    this.releaseNotes,
    this.forceUpdate = false,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> j) => UpdateInfo(
        latestVersion: (j['latestVersion'] ?? '').toString(),
        minRequiredVersion: j['minRequiredVersion']?.toString(),
        downloadUrl: (j['downloadUrl'] ?? '').toString(),
        releaseNotes: j['releaseNotes']?.toString(),
        forceUpdate: j['forceUpdate'] == true,
      );
}

/// 版本号比较：a<b 返回 -1，相等 0，a>b 返回 1。支持 x.y.z。
int compareVersion(String a, String b) {
  final pa = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  final pb = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  while (pa.length < pb.length) pa.add(0);
  while (pb.length < pa.length) pb.add(0);
  for (var i = 0; i < pa.length; i++) {
    if (pa[i] != pb[i]) return pa[i] < pb[i] ? -1 : 1;
  }
  return 0;
}

/// 依次尝试多个镜像拉取远程版本信息；全部失败返回 null（静默跳过更新检查）。
Future<UpdateInfo?> fetchLatestVersion() async {
  if (kIsWeb) return null; // Web 端刷新即更新，不需要应用内更新
  for (final mirror in kGhProxyMirrors) {
    final url = mirror.isEmpty
        ? 'https://$kVersionCheckPath'
        : '$mirror$kVersionCheckPath';
    try {
      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) continue;
      final j = jsonDecode(res.body);
      if (j is! Map<String, dynamic>) continue;
      final info = UpdateInfo.fromJson(j);
      if (info.latestVersion.isEmpty || info.downloadUrl.isEmpty) continue;
      // 把 downloadUrl 的镜像前缀换成当前成功的镜像，保证下载也走通的线路
      final downloadUrl = _rewriteMirror(info.downloadUrl, mirror);
      return UpdateInfo(
        latestVersion: info.latestVersion,
        minRequiredVersion: info.minRequiredVersion,
        downloadUrl: downloadUrl,
        releaseNotes: info.releaseNotes,
        forceUpdate: info.forceUpdate,
      );
    } catch (_) {
      continue;
    }
  }
  return null;
}

/// 把 downloadUrl 里已有的 ghproxy 镜像前缀换成 workingMirror。
/// 若本身是 ghproxy 风格地址则替换前缀；若是别的托管地址（如 Cloudflare），原样返回。
String _rewriteMirror(String url, String workingMirror) {
  for (final m in kGhProxyMirrors) {
    if (m.isNotEmpty && url.startsWith(m)) {
      final rest = url.substring(m.length);
      return workingMirror.isEmpty ? 'https://$rest' : '$workingMirror$rest';
    }
  }
  return url;
}

class UpdateCheckResult {
  final bool needUpdate;
  final bool forceUpdate;
  final UpdateInfo info;
  UpdateCheckResult({
    required this.needUpdate,
    required this.forceUpdate,
    required this.info,
  });
}

/// 判断当前版本是否需要更新。
UpdateCheckResult checkUpdate(UpdateInfo info) {
  final cmp = compareVersion(kCurrentVersion, info.latestVersion);
  if (cmp < 0) {
    final forced = info.forceUpdate ||
        (info.minRequiredVersion != null &&
            compareVersion(kCurrentVersion, info.minRequiredVersion!) < 0);
    return UpdateCheckResult(
        needUpdate: true, forceUpdate: forced, info: info);
  }
  return UpdateCheckResult(needUpdate: false, forceUpdate: false, info: info);
}

/// 触发下载并安装。下载进度(0-100)通过 onProgress 回调；出错走 onError。
/// 真正的下载与安装由 Android 端 MainActivity 的 MethodChannel 完成。
Future<void> startUpdate(
  String downloadUrl, {
  required void Function(int percent) onProgress,
  required void Function(String error) onError,
}) async {
  if (kIsWeb) {
    onError('当前平台不支持应用内更新');
    return;
  }
  final channel = MethodChannel(kAppUpdateChannel);
  channel.setMethodCallHandler((call) async {
    if (call.method == 'progress') {
      final a = call.arguments;
      onProgress(a is int ? a : (a is double ? a.toInt() : 0));
    }
    return null;
  });
  try {
    await channel.invokeMethod<void>('downloadAndInstall', {'url': downloadUrl});
  } on PlatformException catch (e) {
    onError(e.message ?? '更新失败');
  } catch (e) {
    onError(e.toString());
  } finally {
    channel.setMethodCallHandler(null);
  }
}

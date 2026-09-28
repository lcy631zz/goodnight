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

/// 拉取远程版本信息；网络异常/解析失败时返回 null（静默跳过更新检查，不打扰用户）。
Future<UpdateInfo?> fetchLatestVersion() async {
  if (kIsWeb) return null; // Web 端刷新即更新，不需要应用内更新
  try {
    final res = await http
        .get(Uri.parse(kVersionCheckUrl))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return null;
    final j = jsonDecode(res.body);
    if (j is! Map) return null;
    final info = UpdateInfo.fromJson(j);
    if (info.latestVersion.isEmpty || info.downloadUrl.isEmpty) return null;
    return info;
  } catch (_) {
    return null;
  }
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

// 仅非 Web 平台（Android / 桌面）编译进来的实现。
// 这里可以使用 dart:io 的 File / FileImage，处理本地导入的图片文件。
import 'dart:io';
import 'package:flutter/material.dart';

/// 非 http(s) 的本地图片路径 -> FileImage（Android 本地相册导入用）。
ImageProvider<Object> fileImageProvider(String src) => FileImage(File(src));

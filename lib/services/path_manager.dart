import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:path/path.dart' as path;
import 'data_path_service.dart';

/// 负责管理路径转换的工具类
class PathManager {
  static final DataPathService _dataPathService = DataPathService();

  /// 将绝对路径转换为相对路径
  ///
  /// 输入示例: /storage/emulated/0/Download/moments_data/images/abc123.jpg
  /// 输出示例: images/abc123.jpg
  static Future<String> toRelativePath(String absolutePath) async {
    try {
      // 获取自定义根目录
      final rootPath = await _dataPathService.getCustomRootPath();

      // 判断是否包含根目录
      if (absolutePath.startsWith(rootPath)) {
        // 移除根目录前缀
        final relativePath = absolutePath.substring(rootPath.length);

        // 确保路径以/开头
        if (relativePath.startsWith('/')) {
          return relativePath.substring(1); // 移除开头的/
        } else {
          return relativePath;
        }
      }

      // 如果不在自定义路径下，则获取默认内部路径
      final internalPath = await _dataPathService.getDefaultInternalPath();
      if (absolutePath.startsWith(internalPath)) {
        final relativePath = absolutePath.substring(internalPath.length);
        if (relativePath.startsWith('/')) {
          return relativePath.substring(1);
        } else {
          return relativePath;
        }
      }

      if (kDebugMode) {
        print('无法转换为相对路径，路径不在任何已知根目录下: $absolutePath');
      }

      // 如果路径不在任何已知根目录下，尝试仅保留images/之后的部分
      final imageDirIndex = absolutePath.lastIndexOf('images/');
      if (imageDirIndex != -1) {
        return absolutePath.substring(imageDirIndex);
      }

      // 如果仍然无法处理，返回文件名
      return path.basename(absolutePath);
    } catch (e) {
      if (kDebugMode) {
        print('转换相对路径出错: $e');
      }
      // 作为最后的手段，返回原始路径
      return absolutePath;
    }
  }

  /// 将相对路径转换为绝对路径
  ///
  /// 输入示例: images/abc123.jpg
  /// 输出示例: /storage/emulated/0/Download/moments_data/images/abc123.jpg
  static Future<String> toAbsolutePath(String relativePath) async {
    try {
      if (relativePath.isEmpty) {
        throw Exception('相对路径为空');
      }

      // 如果已经是绝对路径，直接返回
      if (path.isAbsolute(relativePath)) {
        if (await File(relativePath).exists()) {
          return relativePath;
        }
      }

      // 首先尝试使用自定义根目录
      final customRoot = await _dataPathService.getCustomRootPath();
      final fullPath = path.join(customRoot, relativePath);

      if (await File(fullPath).exists()) {
        return fullPath;
      }

      // 如果自定义路径下不存在，尝试使用内部存储路径
      final internalPath = await _dataPathService.getDefaultInternalPath();
      final internalFullPath = path.join(internalPath, relativePath);

      if (await File(internalFullPath).exists()) {
        return internalFullPath;
      }

      if (kDebugMode) {
        print('文件在两个位置都不存在，默认使用自定义路径: $fullPath');
      }

      // 默认返回自定义路径下的完整路径
      return fullPath;
    } catch (e) {
      if (kDebugMode) {
        print('转换绝对路径出错: $e');
      }
      // 如果发生错误，返回原始路径
      return relativePath;
    }
  }

  /// 批量将相对路径转换为绝对路径
  static Future<List<String>> toAbsolutePaths(
      List<String> relativePaths) async {
    final List<String> absolutePaths = [];
    for (final relativePath in relativePaths) {
      absolutePaths.add(await toAbsolutePath(relativePath));
    }
    return absolutePaths;
  }
}

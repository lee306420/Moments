import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:path_provider/path_provider.dart';
import '../services/settings_service.dart';
import '../services/data_path_service.dart';
import '../services/moment_service.dart';
import 'package:path/path.dart' as path;

class PathDisplayUtil {
  static final SettingsService _settingsService = SettingsService();

  // 检查图片是否存在
  static Future<bool> verifyImageExists(String filePath) async {
    try {
      final file = File(filePath);
      final exists = await file.exists();
      if (kDebugMode) {
        print('验证图片是否存在: $filePath, 结果: $exists');
        if (exists) {
          final size = await file.length();
          print('图片大小: $size 字节');
        }
      }
      return exists;
    } catch (e) {
      if (kDebugMode) {
        print('验证图片存在性出错: $e');
      }
      return false;
    }
  }

  // 显示保存路径信息对话框
  static Future<void> showSavePathInfo(
      BuildContext context, List<String> savedPaths) async {
    final dataPathService = DataPathService();
    final momentService = MomentService();

    // 获取所有路径
    final customRootPath = await dataPathService.getCustomRootPath();
    final defaultPath = await dataPathService.getDefaultInternalPath();
    final imagesPath = await dataPathService.getImagesPath();
    final dbPath = await dataPathService.getDatabasePath();
    final jsonFilePath = momentService.getJsonFilePath();
    final jsonFileExists = await momentService.validateJsonFile();

    // 验证图片是否存在
    List<Map<String, dynamic>> imageResults = [];
    for (var imagePath in savedPaths) {
      final exists = await verifyImageExists(imagePath);
      imageResults.add({
        'path': imagePath,
        'exists': exists,
      });
    }

    // 检查是否使用了自定义路径
    final appDir = await dataPathService.getDefaultInternalPath();
    final isCustomPathUsed = !imagesPath.startsWith(appDir);

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('保存路径信息'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('配置的存储路径: $customRootPath'),
                const SizedBox(height: 8),
                Text('默认内部路径: $defaultPath'),
                const SizedBox(height: 8),
                Text(
                  '是否使用自定义路径: ${isCustomPathUsed ? "是" : "否"}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isCustomPathUsed ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(height: 16),
                Text('JSON文件路径: $jsonFilePath'),
                Text(
                  'JSON文件是否存在: ${jsonFileExists ? "是" : "否"}',
                  style: TextStyle(
                    color: jsonFileExists ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '图片保存情况:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...imageResults.map((result) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '路径: ${result['path']}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            '文件${result['exists'] ? "存在" : "不存在"}',
                            style: TextStyle(
                              color:
                                  result['exists'] ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Divider(),
                        ],
                      ),
                    )),
              ],
            ),
          ),
          actions: [
            if (!isCustomPathUsed)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showMissingCustomPathHelp(context);
                },
                child: const Text('为什么没有使用自定义路径?'),
              ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    }
  }

  // 显示未使用自定义路径的帮助对话框
  static void _showMissingCustomPathHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('为什么没有使用自定义路径?'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('可能的原因:'),
              SizedBox(height: 8),
              Text('1. 所选路径不可写，应用自动回退到内部存储'),
              Text('2. Android 11+设备需要"管理所有文件"权限'),
              Text('3. 路径验证失败，请检查路径是否有效'),
              SizedBox(height: 16),
              Text('建议操作:'),
              SizedBox(height: 8),
              Text('1. 在设置中重新选择一个路径'),
              Text('2. 确保授予了所有必要的权限'),
              Text('3. 验证路径后再发布动态'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  // 强制拷贝图片到目标位置
  static Future<String?> forceCopyImage(
      String sourcePath, String targetPath) async {
    try {
      if (kDebugMode) {
        print('强制复制图片: $sourcePath -> $targetPath');
      }

      // 确保目标目录存在
      final dir = Directory(path.dirname(targetPath));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // 检查源文件是否存在
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        if (kDebugMode) {
          print('源文件不存在: $sourcePath');
        }
        return null;
      }

      // 复制文件
      final targetFile = File(targetPath);
      await sourceFile.copy(targetPath);

      if (kDebugMode) {
        print('图片复制成功');
        print('目标文件是否存在: ${await targetFile.exists()}');
        print('目标文件大小: ${await targetFile.length()} 字节');
      }

      return targetPath;
    } catch (e) {
      if (kDebugMode) {
        print('复制图片失败: $e');
      }
      return null;
    }
  }
}

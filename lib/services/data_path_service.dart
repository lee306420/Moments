import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'settings_service.dart';

/// 数据路径服务 - 统一管理应用中所有数据的存储路径
class DataPathService {
  static final DataPathService _instance = DataPathService._internal();
  final SettingsService _settingsService = SettingsService();

  // 数据目录名称常量
  static const String DATABASE_DIR = 'database';
  static const String IMAGES_DIR = 'images';
  static const String CACHE_DIR = 'cache';

  // 私有构造函数
  DataPathService._internal();

  // 单例工厂
  factory DataPathService() {
    return _instance;
  }

  /// 获取自定义根目录路径（从设置服务获取）
  Future<String> getCustomRootPath() async {
    final path = await _settingsService.getStoragePath();
    if (kDebugMode) {
      print('获取自定义根目录路径: $path');

      // 验证该路径是否存在且可写
      final isValid = await _validateAndCreatePath(path);
      print('自定义根目录路径有效: $isValid');
    }
    return path;
  }

  /// 获取默认内部存储目录
  Future<String> getDefaultInternalPath() async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/moments_data';
  }

  /// 获取数据库目录路径
  Future<String> getDatabasePath() async {
    try {
      // 首先尝试使用自定义路径
      final customRoot = await getCustomRootPath();
      final dbPath = path.join(customRoot, DATABASE_DIR);

      // 确保目录存在且可写
      final isValid = await _validateAndCreatePath(dbPath);
      if (isValid) {
        if (kDebugMode) {
          print('使用自定义数据库路径: $dbPath');
        }
        return dbPath;
      }

      // 回退到内部存储
      final internalPath = await getDefaultInternalPath();
      final internalDbPath = path.join(internalPath, DATABASE_DIR);
      await _validateAndCreatePath(internalDbPath);

      if (kDebugMode) {
        print('使用内部数据库路径: $internalDbPath');
      }
      return internalDbPath;
    } catch (e) {
      if (kDebugMode) {
        print('获取数据库路径出错: $e');
      }
      // 最终回退
      final appDir = await getApplicationDocumentsDirectory();
      return '${appDir.path}/moments_database';
    }
  }

  /// 获取图片存储目录路径
  Future<String> getImagesPath() async {
    try {
      final customRoot = await getCustomRootPath();
      final imagesPath = path.join(customRoot, IMAGES_DIR);

      final isValid = await _validateAndCreatePath(imagesPath);
      if (isValid) {
        if (kDebugMode) {
          print('使用自定义图片路径: $imagesPath');
        }
        return imagesPath;
      }

      // 回退到内部存储
      final internalPath = await getDefaultInternalPath();
      final internalImagesPath = path.join(internalPath, IMAGES_DIR);
      await _validateAndCreatePath(internalImagesPath);

      if (kDebugMode) {
        print('使用内部图片路径: $internalImagesPath');
      }
      return internalImagesPath;
    } catch (e) {
      if (kDebugMode) {
        print('获取图片路径出错: $e');
      }
      // 最终回退
      final appDir = await getApplicationDocumentsDirectory();
      return '${appDir.path}/moments_images';
    }
  }

  /// 获取缓存目录路径
  Future<String> getCachePath() async {
    try {
      final customRoot = await getCustomRootPath();
      final cachePath = path.join(customRoot, CACHE_DIR);

      final isValid = await _validateAndCreatePath(cachePath);
      if (isValid) {
        if (kDebugMode) {
          print('使用自定义缓存路径: $cachePath');
        }
        return cachePath;
      }

      // 回退到内部存储
      final cacheDir = await getTemporaryDirectory();
      final internalCachePath = '${cacheDir.path}/moments_cache';
      await _validateAndCreatePath(internalCachePath);

      if (kDebugMode) {
        print('使用内部缓存路径: $internalCachePath');
      }
      return internalCachePath;
    } catch (e) {
      if (kDebugMode) {
        print('获取缓存路径出错: $e');
      }
      // 最终回退
      final cacheDir = await getTemporaryDirectory();
      return '${cacheDir.path}/moments_cache';
    }
  }

  /// 验证并创建目录路径
  Future<bool> _validateAndCreatePath(String dirPath) async {
    try {
      if (kDebugMode) {
        print('验证并创建路径: $dirPath');
      }

      final directory = Directory(dirPath);

      // 检查目录是否存在
      if (!await directory.exists()) {
        if (kDebugMode) {
          print('目录不存在，尝试创建: $dirPath');
        }

        try {
          await directory.create(recursive: true);
          if (kDebugMode) {
            print('目录创建成功: $dirPath');
          }
        } catch (e) {
          if (kDebugMode) {
            print('创建目录失败: $dirPath, 错误: $e');
          }
          return false;
        }
      } else {
        if (kDebugMode) {
          print('目录已存在: $dirPath');
        }
      }

      // 验证目录是否可写
      try {
        // 生成唯一的测试文件名，避免冲突
        final testFileName =
            'test_write_${DateTime.now().millisecondsSinceEpoch}.tmp';
        final testFile = File(path.join(dirPath, testFileName));
        if (kDebugMode) {
          print('尝试写入测试文件: ${testFile.path}');
        }

        await testFile.writeAsString('test');
        await testFile.delete();

        if (kDebugMode) {
          print('目录可写: $dirPath');
        }
        return true;
      } catch (e) {
        if (kDebugMode) {
          print('目录不可写: $dirPath, 错误: $e');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('验证路径失败: $dirPath, 错误: $e');
      }
      return false;
    }
  }

  /// 迁移现有数据到新路径
  Future<bool> migrateDataToNewPath(String oldPath, String newPath) async {
    try {
      if (kDebugMode) {
        print('尝试迁移数据从 $oldPath 到 $newPath');
      }

      final oldDir = Directory(oldPath);
      final newDir = Directory(newPath);

      // 确保旧目录存在
      if (!await oldDir.exists()) {
        if (kDebugMode) {
          print('旧目录不存在，无需迁移');
        }
        return true;
      }

      // 确保新目录存在
      if (!await newDir.exists()) {
        await newDir.create(recursive: true);
      }

      // 复制所有文件
      final files = await oldDir.list().toList();
      for (var entity in files) {
        if (entity is File) {
          final fileName = path.basename(entity.path);
          final newFilePath = path.join(newPath, fileName);

          if (kDebugMode) {
            print('复制文件: ${entity.path} -> $newFilePath');
          }

          await entity.copy(newFilePath);
        }
      }

      if (kDebugMode) {
        print('数据迁移成功');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('迁移数据失败: $e');
      }
      return false;
    }
  }
}

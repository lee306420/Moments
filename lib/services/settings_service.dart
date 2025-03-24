import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;

class SettingsService {
  static const String _settingsFileName = 'settings.json';
  static final SettingsService _instance = SettingsService._internal();
  static const String _storagePathKey = 'storage_path';

  bool _isInitialized = false;
  Map<String, dynamic> _settings = {};
  late String _settingsFilePath;

  factory SettingsService() {
    return _instance;
  }

  SettingsService._internal();

  Future<void> init() async {
    if (_isInitialized) return;

    if (kDebugMode) {
      print('初始化SettingsService...');
    }

    try {
      // 获取应用文档目录
      final appDocDir = await getApplicationDocumentsDirectory();
      _settingsFilePath = '${appDocDir.path}/$_settingsFileName';

      if (kDebugMode) {
        print('设置文件路径: $_settingsFilePath');
      }

      // 检查设置文件是否存在
      final settingsFile = File(_settingsFilePath);
      if (await settingsFile.exists()) {
        final jsonString = await settingsFile.readAsString();
        _settings = jsonDecode(jsonString) as Map<String, dynamic>;

        if (kDebugMode) {
          print('已从文件加载设置');
        }
      } else {
        if (kDebugMode) {
          print('设置文件不存在，创建默认设置');
        }

        // 如果存储路径不存在，设置默认路径
        if (!_settings.containsKey(_storagePathKey)) {
          final defaultPath = await _getDefaultStoragePath();
          if (kDebugMode) {
            print('设置默认存储路径: $defaultPath');
          }
          _settings[_storagePathKey] = defaultPath;
          await _saveSettings();
        }
      }

      // 验证已保存的路径是否可用
      final savedPath = _settings[_storagePathKey] as String?;
      if (kDebugMode) {
        print('验证已保存路径: $savedPath');
      }

      if (savedPath != null) {
        final isValid = await _isPathValid(savedPath);
        if (!isValid) {
          // 如果已保存的路径无效，重置为默认路径
          final defaultPath = await _getDefaultStoragePath();
          _settings[_storagePathKey] = defaultPath;
          await _saveSettings();

          if (kDebugMode) {
            print('已保存的路径无效，已重置为默认路径: $defaultPath');
          }
        } else {
          if (kDebugMode) {
            print('已保存的路径有效: $savedPath');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('初始化设置服务出错: $e');
      }

      // 出错时设置默认值
      final defaultPath = await _getDefaultStoragePath();
      _settings[_storagePathKey] = defaultPath;
    }

    _isInitialized = true;
  }

  // 保存设置到文件
  Future<void> _saveSettings() async {
    try {
      final settingsFile = File(_settingsFilePath);
      final dir = Directory(path.dirname(settingsFile.path));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final jsonString = JsonEncoder.withIndent('  ').convert(_settings);
      await settingsFile.writeAsString(jsonString);

      if (kDebugMode) {
        print('设置已保存到文件');
      }
    } catch (e) {
      if (kDebugMode) {
        print('保存设置出错: $e');
      }
    }
  }

  // 获取默认存储路径
  Future<String> _getDefaultStoragePath() async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/moments_data';
  }

  // 验证路径是否有效且可写
  Future<bool> _isPathValid(String path) async {
    if (kDebugMode) {
      print('验证路径有效性: $path');
    }

    try {
      final directory = Directory(path);
      // 检查目录是否存在
      if (!await directory.exists()) {
        if (kDebugMode) {
          print('目录不存在，尝试创建: $path');
        }

        try {
          // 尝试创建目录
          await directory.create(recursive: true);
          if (kDebugMode) {
            print('目录创建成功');
          }
        } catch (e) {
          if (kDebugMode) {
            print('无法创建目录: $e');
          }
          return false;
        }
      } else {
        if (kDebugMode) {
          print('目录已存在');
        }
      }

      // 检查目录是否可写
      try {
        final testFile = File('$path/test_write.tmp');
        if (kDebugMode) {
          print('尝试写入测试文件');
        }
        await testFile.writeAsString('test');
        await testFile.delete();
        if (kDebugMode) {
          print('测试文件写入成功，路径有效');
        }
        return true;
      } catch (e) {
        if (kDebugMode) {
          print('目录不可写: $e');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('路径无效: $e');
      }
      return false;
    }
  }

  // 检查存储权限
  Future<bool> _checkStoragePermission() async {
    if (kDebugMode) {
      print('检查存储权限');
    }

    try {
      // 基本存储权限
      bool hasPermission = await Permission.storage.isGranted;

      if (kDebugMode) {
        print('基本存储权限: $hasPermission');
      }

      // Android 11+ 需要特殊权限
      if (Platform.isAndroid) {
        final sdkVersion = await _getAndroidSdkVersion();
        if (sdkVersion >= 30) {
          bool hasManagePermission =
              await Permission.manageExternalStorage.isGranted;
          if (kDebugMode) {
            print('管理外部存储权限: $hasManagePermission');
          }
          return hasManagePermission;
        }
      }

      return hasPermission;
    } catch (e) {
      if (kDebugMode) {
        print('检查权限时出错: $e');
      }
      return false;
    }
  }

  // 获取Android SDK版本
  Future<int> _getAndroidSdkVersion() async {
    if (!Platform.isAndroid) {
      return 0;
    }

    try {
      // 简化处理，实际应用中应该使用platform channel
      return 30; // 假设为Android 11
    } catch (e) {
      if (kDebugMode) {
        print('获取Android SDK版本出错: $e');
      }
      return 29; // 默认为Android 10
    }
  }

  // 获取当前存储路径
  Future<String> getStoragePath() async {
    await _ensureInitialized();

    final path = _settings[_storagePathKey] as String?;
    if (path == null) {
      final defaultPath = await _getDefaultStoragePath();
      _settings[_storagePathKey] = defaultPath;
      await _saveSettings();
      return defaultPath;
    }

    // 再次验证路径，如果无效返回默认路径
    final isValid = await _isPathValid(path);
    if (!isValid) {
      if (kDebugMode) {
        print('获取时发现路径无效，使用默认路径');
      }
      final defaultPath = await _getDefaultStoragePath();
      return defaultPath; // 返回默认路径但不更新设置
    }

    return path;
  }

  // 设置新的存储路径
  Future<bool> setStoragePath(String newPath) async {
    try {
      if (kDebugMode) {
        print('设置新的存储路径: $newPath');
      }

      // 验证新路径是否有效
      final isValid = await _isPathValid(newPath);
      if (!isValid) {
        if (kDebugMode) {
          print('新路径无效或不可写');
        }
        return false;
      }

      await _ensureInitialized();
      _settings[_storagePathKey] = newPath;
      await _saveSettings();

      if (kDebugMode) {
        print('存储路径设置成功: $newPath');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('设置存储路径失败: $e');
      }
      return false;
    }
  }

  // 重置为默认存储路径
  Future<void> resetToDefaultPath() async {
    final defaultPath = await _getDefaultStoragePath();
    if (kDebugMode) {
      print('重置为默认路径: $defaultPath');
    }
    await setStoragePath(defaultPath);
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await init();
    }
  }
}

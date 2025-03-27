import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import '../services/settings_service.dart';
import '../services/data_path_service.dart';
import '../services/path_manager.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:flutter/material.dart';

class ImageUtils {
  static final ImagePicker _picker = ImagePicker();
  static final SettingsService _settingsService = SettingsService();
  static final DataPathService _dataPathService = DataPathService();

  // 使用微信风格选择器选择多张图片
  static Future<List<File>> pickImagesWithWechat(BuildContext context,
      {int maxAssets = 9}) async {
    final List<AssetEntity>? result = await AssetPicker.pickAssets(
      context,
      pickerConfig: AssetPickerConfig(
        maxAssets: maxAssets,
        requestType: RequestType.image,
      ),
    );

    if (result == null || result.isEmpty) {
      return [];
    }

    List<File> files = [];
    for (var asset in result) {
      final file = await asset.file;
      if (file != null) {
        files.add(file);
      }
    }

    return files;
  }

  // 使用微信风格选择器选择视频
  static Future<File?> pickVideoWithWechat(BuildContext context) async {
    final List<AssetEntity>? result = await AssetPicker.pickAssets(
      context,
      pickerConfig: const AssetPickerConfig(
        maxAssets: 1,
        requestType: RequestType.video,
      ),
    );

    if (result == null || result.isEmpty) {
      return null;
    }

    return await result.first.file;
  }

  // 从相册选择多张图片
  static Future<List<File>> pickImages() async {
    final List<XFile> pickedFiles = await _picker.pickMultiImage();
    return pickedFiles.map((file) => File(file.path)).toList();
  }

  // 拍照
  static Future<File?> takePhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      return File(photo.path);
    }
    return null;
  }

  // 检查和请求存储权限
  static Future<bool> _requestStoragePermission() async {
    try {
      // 检查基本存储权限
      PermissionStatus status = await Permission.storage.status;

      if (kDebugMode) {
        print('存储权限状态: $status');
      }

      if (!status.isGranted) {
        // 请求权限
        if (kDebugMode) {
          print('请求基本存储权限');
        }
        status = await Permission.storage.request();
        if (kDebugMode) {
          print('请求后状态: $status');
        }
        if (!status.isGranted) {
          return false;
        }
      }

      // 对于Android 11+，检查管理外部存储权限
      if (Platform.isAndroid) {
        final sdkVersion = await _getAndroidSdkVersion();
        if (kDebugMode) {
          print('Android SDK 版本: $sdkVersion');
        }

        if (sdkVersion >= 30) {
          // Android 11 (API 30) 及以上
          final externalStatus = await Permission.manageExternalStorage.status;
          if (kDebugMode) {
            print('管理外部存储权限状态: $externalStatus');
          }

          if (!externalStatus.isGranted) {
            // 请求权限
            if (kDebugMode) {
              print('请求管理外部存储权限');
            }
            await Permission.manageExternalStorage.request();
            final newStatus = await Permission.manageExternalStorage.status;
            if (kDebugMode) {
              print('请求后状态: $newStatus');
            }
            // 用户需要在设置中手动授予此权限，所以再次检查状态
            return newStatus.isGranted;
          }
        }
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('请求权限时出错: $e');
      }
      return false;
    }
  }

  // 获取Android SDK版本
  static Future<int> _getAndroidSdkVersion() async {
    if (!Platform.isAndroid) {
      return 0;
    }

    try {
      // 实际应用中可能需要使用platform channel获取真实SDK版本
      // 这里为了简化，返回一个常数
      return 30; // 假设为Android 11
    } catch (e) {
      if (kDebugMode) {
        print('获取Android SDK版本出错: $e');
      }
      return 29; // 默认为Android 10
    }
  }

  // 保存图片到自定义目录
  static Future<String> saveImageToLocal(File imageFile) async {
    try {
      // 获取用户设置的图片存储路径
      final String imagesDir = await _dataPathService.getImagesPath();
      if (kDebugMode) {
        print('===== 存储诊断信息 =====');
        print('尝试保存图片到: $imagesDir');
      }

      // 检查是否需要请求权限（非应用内部目录）
      final appDir = await getApplicationDocumentsDirectory();
      final isExternalPath = !imagesDir.startsWith(appDir.path);

      if (kDebugMode) {
        print('是外部存储路径: $isExternalPath');
        if (isExternalPath) {
          print('外部存储路径: $imagesDir');
        }
      }

      // 生成唯一的文件名，无论路径如何，都预先准备好文件名
      final String fileName =
          '${const Uuid().v4()}${path.extension(imageFile.path)}';
      final String targetPath = '$imagesDir/$fileName';
      // 备用内部存储路径
      final internalPath = await _dataPathService.getDefaultInternalPath();
      final String internalBackupPath = '$internalPath/images/$fileName';

      if (kDebugMode) {
        print('目标路径: $targetPath');
        print('备用内部路径: $internalBackupPath');
      }

      // 1. 首先，尝试直接复制到目标路径 (不论是否外部路径)
      try {
        // 确保目录存在
        final Directory targetDir = Directory(imagesDir);
        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
          if (kDebugMode) {
            print('已创建目录: $imagesDir');
          }
        }

        // 直接复制
        await imageFile.copy(targetPath);

        // 验证文件是否真的复制成功
        final fileExists = await File(targetPath).exists();
        if (fileExists) {
          if (kDebugMode) {
            print('成功保存到指定路径: $targetPath');
            print('===== 存储诊断结束 =====');
          }
          // 返回相对路径以便存储到JSON
          final relativePath = await PathManager.toRelativePath(targetPath);
          if (kDebugMode) {
            print('存储相对路径: $relativePath');
          }
          return targetPath; // 仍然返回绝对路径以便立即使用
        } else {
          throw Exception('复制成功但文件不存在');
        }
      } catch (e) {
        if (kDebugMode) {
          print('直接复制失败，错误: $e');
        }
      }

      // 2. 如果直接复制失败并且是外部路径，尝试获取权限并再次尝试
      if (isExternalPath) {
        if (kDebugMode) {
          print('尝试获取权限后再复制');
        }

        final hasPermission = await _requestStoragePermission();

        if (hasPermission) {
          try {
            // 再次确保目录存在
            final Directory targetDir = Directory(imagesDir);
            if (!await targetDir.exists()) {
              await targetDir.create(recursive: true);
            }

            // 再次尝试复制
            await imageFile.copy(targetPath);

            // 验证文件是否存在
            final fileExists = await File(targetPath).exists();
            if (fileExists) {
              if (kDebugMode) {
                print('获取权限后成功保存: $targetPath');
                print('===== 存储诊断结束 =====');
              }
              // 返回相对路径以便存储到JSON
              final relativePath = await PathManager.toRelativePath(targetPath);
              if (kDebugMode) {
                print('存储相对路径: $relativePath');
              }
              return targetPath;
            }
          } catch (e) {
            if (kDebugMode) {
              print('获取权限后复制仍然失败: $e');
            }
          }
        }
      }

      // 3. 以上都失败，回退到内部存储
      if (kDebugMode) {
        print('回退到内部存储');
      }

      String fallbackPath = await _saveToInternalStorage(imageFile, fileName);

      if (kDebugMode) {
        print('已保存到内部存储: $fallbackPath');
        print('===== 存储诊断结束 =====');
      }

      return fallbackPath;
    } catch (e) {
      if (kDebugMode) {
        print('保存图片时发生未知错误: $e');
      }
      // 使用内部存储作为最后的后备选项
      return _saveToInternalStorage(imageFile);
    }
  }

  // 保存到应用内部存储的辅助方法
  static Future<String> _saveToInternalStorage(File imageFile,
      [String? predefinedFileName]) async {
    try {
      final internalPath = await _dataPathService.getDefaultInternalPath();
      final fallbackDir = '$internalPath/images';
      final fallbackDirFile = Directory(fallbackDir);
      if (!await fallbackDirFile.exists()) {
        await fallbackDirFile.create(recursive: true);
      }

      final fileName = predefinedFileName ??
          '${const Uuid().v4()}${path.extension(imageFile.path)}';
      final fallbackPath = '$fallbackDir/$fileName';
      await imageFile.copy(fallbackPath);

      if (kDebugMode) {
        print('已回退到内部存储: $fallbackPath');
      }

      return fallbackPath;
    } catch (e) {
      if (kDebugMode) {
        print('保存到内部存储也失败了: $e');
      }
      // 如果内部存储也失败，返回原始文件路径
      return imageFile.path;
    }
  }

  // 保存多张图片
  static Future<List<String>> saveImagesToLocal(List<File> imageFiles) async {
    final List<String> savedPaths = [];
    for (var file in imageFiles) {
      try {
        final savedPath = await saveImageToLocal(file);
        savedPaths.add(savedPath);
      } catch (e) {
        // 如果某张图片保存失败，继续保存其他图片
        if (kDebugMode) {
          print('保存图片失败: $e');
        }
      }
    }
    return savedPaths;
  }
}

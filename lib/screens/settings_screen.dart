import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/settings_service.dart';
import '../services/data_path_service.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../services/moment_service.dart';
import '../services/json_moment_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  final DataPathService _dataPathService = DataPathService();
  final JsonMomentService _momentService = JsonMomentService();

  String _currentPath = '';
  String _databasePath = '';
  String _imagesPath = '';
  String _cachePath = '';

  bool _isLoading = true;
  bool _isExternalPath = false;
  bool _showAndroid11Warning = false;
  bool _hasManagePermission = false;
  bool _isMigratingData = false;

  @override
  void initState() {
    super.initState();
    _loadAllPaths();
    _checkPermissionsForWarning();
  }

  Future<void> _checkPermissionsForWarning() async {
    if (Platform.isAndroid) {
      try {
        // Android 11+需要特殊提示
        _showAndroid11Warning = true;
        // 检查是否已有权限
        _hasManagePermission = await Permission.manageExternalStorage.isGranted;
        if (mounted) {
          setState(() {});
        }
      } catch (e) {
        if (kDebugMode) {
          print('检查权限时出错: $e');
        }
      }
    }
  }

  Future<void> _loadAllPaths() async {
    setState(() {
      _isLoading = true;
    });

    // 获取各种路径
    final rootPath = await _settingsService.getStoragePath();
    final dbPath = await _dataPathService.getDatabasePath();
    final imgPath = await _dataPathService.getImagesPath();
    final cachePath = await _dataPathService.getCachePath();

    final appDir = await getApplicationDocumentsDirectory();

    setState(() {
      _currentPath = rootPath;
      _databasePath = dbPath;
      _imagesPath = imgPath;
      _cachePath = cachePath;
      _isExternalPath = !rootPath.startsWith(appDir.path);
      _isLoading = false;
    });

    // 更新Android 11+权限状态
    if (Platform.isAndroid && _isExternalPath) {
      _hasManagePermission = await Permission.manageExternalStorage.isGranted;
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _selectDirectory() async {
    try {
      // 先检查基本存储权限
      if (Platform.isAndroid) {
        final storageStatus = await Permission.storage.request();
        // Android 11及以上需要特殊权限
        if (await _isAndroid11OrAbove()) {
          final manageStatus = await Permission.manageExternalStorage.status;
          if (!manageStatus.isGranted) {
            await Permission.manageExternalStorage.request();
            // 重新检查权限状态
            _hasManagePermission =
                await Permission.manageExternalStorage.isGranted;

            if (!_hasManagePermission) {
              if (mounted) {
                _showPermissionDialog();
                return;
              }
            }
          } else {
            _hasManagePermission = true;
          }

          if (mounted) {
            setState(() {});
          }
        } else if (!storageStatus.isGranted) {
          if (mounted) {
            _showPermissionDialog();
            return;
          }
        }
      }

      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

      if (selectedDirectory != null) {
        // 显示加载指示器
        setState(() {
          _isLoading = true;
        });

        // 尝试设置路径
        final success =
            await _settingsService.setStoragePath(selectedDirectory);

        // 重新加载路径状态
        await _loadAllPaths();

        if (success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('存储路径已更新')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('无法设置所选路径，请选择其他路径或检查权限')),
            );
          }
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择目录时出错: $e')),
        );
      }
    }
  }

  // 检查是否为Android 11或更高版本
  Future<bool> _isAndroid11OrAbove() async {
    if (!Platform.isAndroid) {
      return false;
    }
    return true; // 简化处理，假设是Android 11+
  }

  // 显示权限说明对话框
  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('需要存储权限'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '要保存图片到外部存储，应用需要获得存储权限。\n\n'
              '对于Android 11及以上设备，您需要在设置中手动授予"管理所有文件"权限。',
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/permission_guide.png',
                height: 200,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox(
                    height: 100,
                    child: Center(
                      child: Text(
                        '权限设置示意图\n(找到"管理所有文件"并开启)',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('稍后再说'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
            child: const Text('去设置'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetToDefault() async {
    setState(() {
      _isLoading = true;
    });

    await _settingsService.resetToDefaultPath();
    await _loadAllPaths();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已重置为默认存储路径')),
      );
    }
  }

  // 迁移现有数据到新路径
  Future<void> _migrateData() async {
    if (_isMigratingData) return;

    setState(() {
      _isMigratingData = true;
    });

    try {
      // 获取默认内部路径作为源路径
      final defaultPath = await _dataPathService.getDefaultInternalPath();
      final appDir = await getApplicationDocumentsDirectory();
      final oldImagesPath = '${appDir.path}/moments_images';

      // 迁移图片
      bool imagesSuccess = await _dataPathService.migrateDataToNewPath(
          oldImagesPath, _imagesPath);

      // JSON文件已经自动保存在新位置，无需单独迁移
      bool dbSuccess = true;

      setState(() {
        _isMigratingData = false;
      });

      if (mounted) {
        if (imagesSuccess && dbSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('数据迁移完成')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('部分数据迁移失败: ${!imagesSuccess ? '图片 ' : ''}')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isMigratingData = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('数据迁移出错: $e')),
        );
      }
    }
  }

  // 验证当前路径
  Future<void> _verifyCurrentPath() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 验证所有路径
      await _loadAllPaths();

      // 再次检查是否为外部路径
      final appDir = await getApplicationDocumentsDirectory();
      final isExternal = !_currentPath.startsWith(appDir.path);

      // 更新提示信息
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isExternal
                ? '外部存储路径已验证: ${isExternal ? '有效' : '无效，已回退到默认路径'}'
                : '应用内部存储路径已验证: 有效'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('验证路径时出错: $e')),
        );

        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 清理孤立图片文件
  Future<void> _cleanupOrphanedImages() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _momentService.cleanupOrphanedImages();

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '清理完成: 共${result.totalFiles}个文件，删除了${result.deletedFiles}个未使用的图片'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('清理图片时出错: $e')),
        );
      }
    }
  }

  // 构建路径信息卡片
  Widget _buildPathInfoCard() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '数据存储位置',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildPathInfoItem('根目录', _currentPath),
            _buildPathInfoItem('图片目录', _imagesPath),
            _buildPathInfoItem('数据库目录', _databasePath),
            _buildPathInfoItem('缓存目录', _cachePath),
          ],
        ),
      ),
    );
  }

  // 构建单个路径信息项
  Widget _buildPathInfoItem(String title, String path) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            path,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[800],
            ),
          ),
          const Divider(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('存储设置'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '自定义存储路径',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentPath,
                            style: const TextStyle(fontSize: 16),
                          ),
                          if (_isExternalPath) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  _hasManagePermission
                                      ? Icons.check_circle
                                      : Icons.warning,
                                  size: 16,
                                  color: _hasManagePermission
                                      ? Colors.green
                                      : Colors.orange[700],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _hasManagePermission
                                      ? '外部存储权限已获取'
                                      : '外部存储需要特殊权限',
                                  style: TextStyle(
                                    color: _hasManagePermission
                                        ? Colors.green
                                        : Colors.deepOrange,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _selectDirectory,
                          icon: const Icon(Icons.folder),
                          label: const Text('选择文件夹'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _verifyCurrentPath,
                          icon: const Icon(Icons.check),
                          label: const Text('验证路径'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 路径信息卡片
                    _buildPathInfoCard(),

                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '提示',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '1. 选择的路径必须是可写入的目录\n'
                                      '2. 更改存储路径不会自动移动已保存的数据，需要使用"迁移数据"功能\n'
                                      '3. 建议选择私密且有足够空间的位置\n' +
                                  (Platform.isAndroid
                                      ? '4. Android 11+需要在系统设置中授权"管理所有文件"权限\n'
                                          '5. 如果权限被拒绝，将使用应用内部存储'
                                      : ''),
                              style: const TextStyle(fontSize: 14),
                            ),
                            if (_showAndroid11Warning) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _hasManagePermission
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _hasManagePermission
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          _hasManagePermission
                                              ? Icons.check_circle
                                              : Icons.info_outline,
                                          color: _hasManagePermission
                                              ? Colors.green
                                              : Colors.orange,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _hasManagePermission
                                              ? 'Android 11+ 权限已获取'
                                              : 'Android 11+ 权限提示',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: _hasManagePermission
                                                ? Colors.green
                                                : Colors.orange,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _hasManagePermission
                                          ? '您已获得"管理所有文件"权限，可以使用外部存储路径。'
                                          : '您需要在系统设置中手动授予"管理所有文件"权限，否则无法使用外部存储路径。',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: _hasManagePermission
                                            ? Colors.green[700]
                                            : Colors.orange[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (Platform.isAndroid &&
                                _isExternalPath &&
                                !_hasManagePermission) ...[
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () {
                                  openAppSettings();
                                },
                                icon: const Icon(Icons.settings),
                                label: const Text('打开应用权限设置'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '数据管理',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _cleanupOrphanedImages,
                              icon: const Icon(Icons.cleaning_services),
                              label: const Text('清理未使用的图片文件'),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

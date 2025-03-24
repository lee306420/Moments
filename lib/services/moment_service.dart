import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import '../models/moment.dart';
import 'data_path_service.dart';

class MomentService {
  static const String _jsonFileName = 'moments.json';
  static final MomentService _instance = MomentService._internal();
  final DataPathService _dataPathService = DataPathService();
  final List<Moment> _moments = [];
  bool _isInitialized = false;
  late String _jsonFilePath;

  factory MomentService() {
    return _instance;
  }

  MomentService._internal();

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // 获取数据库目录路径
      final dbDir = await _dataPathService.getDatabasePath();
      _jsonFilePath = path.join(dbDir, _jsonFileName);

      if (kDebugMode) {
        print('MomentService初始化，JSON文件路径: $_jsonFilePath');
      }

      // 检查JSON文件是否存在
      final jsonFile = File(_jsonFilePath);
      if (await jsonFile.exists()) {
        // 从文件读取数据
        final jsonString = await jsonFile.readAsString();
        final jsonData = jsonDecode(jsonString) as List<dynamic>;

        _moments.clear();
        for (var item in jsonData) {
          _moments.add(_momentFromJson(item));
        }

        if (kDebugMode) {
          print('从JSON加载了 ${_moments.length} 条动态');
        }
      } else {
        if (kDebugMode) {
          print('JSON文件不存在，创建新的空数据库');
        }
        // 创建空数据文件
        await _saveToJson();
      }

      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) {
        print('MomentService初始化出错: $e');
      }
      // 出错时创建空数据
      _moments.clear();
      _isInitialized = true;
    }
  }

  Future<List<Moment>> getAllMoments() async {
    await _ensureInitialized();
    // 返回列表副本，按时间降序排序
    return _moments.toList()
      ..sort((a, b) => b.createTime.compareTo(a.createTime));
  }

  Future<void> addMoment(Moment moment) async {
    await _ensureInitialized();

    // 检查ID是否已存在
    final index = _moments.indexWhere((m) => m.id == moment.id);
    if (index >= 0) {
      _moments[index] = moment;
    } else {
      _moments.add(moment);
    }

    // 保存到JSON
    await _saveToJson();
  }

  Future<void> updateMoment(Moment moment) async {
    await addMoment(moment); // 复用添加逻辑
  }

  Future<void> deleteMoment(String id) async {
    await _ensureInitialized();

    // 查找要删除的动态，以获取其图片路径
    final momentIndex = _moments.indexWhere((m) => m.id == id);
    if (momentIndex < 0) {
      // 动态不存在
      return;
    }

    // 保存图片路径，以便后续删除
    final imagePaths = List<String>.from(_moments[momentIndex].imagePaths);

    // 从内存中移除动态
    _moments.removeAt(momentIndex);

    // 保存到JSON
    await _saveToJson();

    // 删除关联的图片文件
    for (var imagePath in imagePaths) {
      try {
        final imageFile = File(imagePath);
        if (await imageFile.exists()) {
          await imageFile.delete();
          if (kDebugMode) {
            print('成功删除图片: $imagePath');
          }
        } else {
          if (kDebugMode) {
            print('图片不存在，无需删除: $imagePath');
          }
        }
      } catch (e) {
        // 图片删除失败不影响主流程
        if (kDebugMode) {
          print('删除图片失败: $imagePath, 错误: $e');
        }
      }
    }
  }

  Future<void> addComment(String momentId, Comment comment) async {
    await _ensureInitialized();

    final momentIndex = _moments.indexWhere((m) => m.id == momentId);
    if (momentIndex < 0) {
      if (kDebugMode) {
        print('添加评论失败: 动态ID $momentId 不存在');
      }
      return;
    }

    _moments[momentIndex].comments.add(comment);

    // 保存到JSON
    await _saveToJson();
  }

  Future<void> toggleLike(String momentId) async {
    await _ensureInitialized();

    final momentIndex = _moments.indexWhere((m) => m.id == momentId);
    if (momentIndex < 0) {
      if (kDebugMode) {
        print('点赞失败: 动态ID $momentId 不存在');
      }
      return;
    }

    _moments[momentIndex].likes += 1;

    // 保存到JSON
    await _saveToJson();
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await init();
    }
  }

  String generateId() {
    return const Uuid().v4();
  }

  // 保存到JSON文件
  Future<void> _saveToJson() async {
    try {
      // 确保目录存在
      final jsonFile = File(_jsonFilePath);
      final dir = Directory(path.dirname(jsonFile.path));
      if (!await dir.exists()) {
        if (kDebugMode) {
          print('创建目录: ${dir.path}');
        }
        await dir.create(recursive: true);
      }

      // 验证目录是否可写
      try {
        final testFile = File('${dir.path}/test_write.tmp');
        await testFile.writeAsString('test');
        await testFile.delete();
        if (kDebugMode) {
          print('目录可写: ${dir.path}');
        }
      } catch (e) {
        if (kDebugMode) {
          print('目录不可写，可能无法保存JSON: ${dir.path}, 错误: $e');
        }
        throw Exception('目录不可写: ${dir.path}');
      }

      // 转换为JSON
      final jsonData = _moments.map((m) => _momentToJson(m)).toList();
      final jsonString = JsonEncoder.withIndent('  ').convert(jsonData);

      // 写入文件
      await jsonFile.writeAsString(jsonString);

      if (kDebugMode) {
        print('成功保存 ${_moments.length} 条动态到JSON: $_jsonFilePath');
        print('文件大小: ${await jsonFile.length()} 字节');
        print('文件是否存在: ${await jsonFile.exists()}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('保存JSON数据出错: $e');
      }
      rethrow; // 重新抛出异常以便上层处理
    }
  }

  // 将Moment对象转换为JSON
  Map<String, dynamic> _momentToJson(Moment moment) {
    return {
      'id': moment.id,
      'content': moment.content,
      'imagePaths': moment.imagePaths,
      'createTime': moment.createTime.toIso8601String(),
      'likes': moment.likes,
      'comments': moment.comments.map((c) => _commentToJson(c)).toList(),
      'authorName': moment.authorName,
      'authorAvatar': moment.authorAvatar,
    };
  }

  // 将Comment对象转换为JSON
  Map<String, dynamic> _commentToJson(Comment comment) {
    return {
      'id': comment.id,
      'content': comment.content,
      'createTime': comment.createTime.toIso8601String(),
      'authorName': comment.authorName,
      'authorAvatar': comment.authorAvatar,
    };
  }

  // 从JSON创建Moment对象
  Moment _momentFromJson(Map<String, dynamic> json) {
    final commentsList = (json['comments'] as List<dynamic>)
        .map((c) => _commentFromJson(c as Map<String, dynamic>))
        .toList();

    return Moment(
      id: json['id'] as String,
      content: json['content'] as String,
      imagePaths: (json['imagePaths'] as List<dynamic>).cast<String>(),
      createTime: DateTime.parse(json['createTime'] as String),
      likes: json['likes'] as int,
      comments: commentsList,
      authorName: json['authorName'] as String,
      authorAvatar: json['authorAvatar'] as String?,
    );
  }

  // 从JSON创建Comment对象
  Comment _commentFromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] as String,
      content: json['content'] as String,
      createTime: DateTime.parse(json['createTime'] as String),
      authorName: json['authorName'] as String,
      authorAvatar: json['authorAvatar'] as String?,
    );
  }

  // 获取当前JSON文件路径
  String getJsonFilePath() {
    return _jsonFilePath;
  }

  // 验证JSON文件是否存在
  Future<bool> validateJsonFile() async {
    await _ensureInitialized();
    final file = File(_jsonFilePath);
    final exists = await file.exists();
    if (kDebugMode) {
      print('验证JSON文件存在性: $_jsonFilePath, 结果: $exists');
    }
    return exists;
  }

  // 清理孤立的图片文件
  Future<CleanupResult> cleanupOrphanedImages() async {
    await _ensureInitialized();

    final dataPathService = DataPathService();
    final imagesDir = await dataPathService.getImagesPath();

    int totalFiles = 0;
    int deletedFiles = 0;
    int failedFiles = 0;
    List<String> keepFiles = [];

    try {
      // 首先收集所有动态中引用的图片路径
      final Set<String> referencedImages = <String>{};
      for (var moment in _moments) {
        referencedImages.addAll(moment.imagePaths);
      }

      // 获取图片目录中的所有文件
      final directory = Directory(imagesDir);
      if (await directory.exists()) {
        final List<FileSystemEntity> files = await directory.list().toList();
        totalFiles = files.length;

        for (var entity in files) {
          if (entity is File) {
            final filePath = entity.path;

            // 检查是否在引用列表中
            if (!referencedImages.contains(filePath)) {
              try {
                await entity.delete();
                if (kDebugMode) {
                  print('删除孤立图片: $filePath');
                }
                deletedFiles++;
              } catch (e) {
                if (kDebugMode) {
                  print('删除孤立图片失败: $filePath, 错误: $e');
                }
                failedFiles++;
              }
            } else {
              keepFiles.add(filePath);
            }
          }
        }
      }

      return CleanupResult(
        totalFiles: totalFiles,
        deletedFiles: deletedFiles,
        failedFiles: failedFiles,
        keptFiles: keepFiles.length,
      );
    } catch (e) {
      if (kDebugMode) {
        print('清理孤立图片文件出错: $e');
      }

      return CleanupResult(
        totalFiles: totalFiles,
        deletedFiles: deletedFiles,
        failedFiles:
            failedFiles + (totalFiles - deletedFiles - keepFiles.length),
        keptFiles: keepFiles.length,
        error: e.toString(),
      );
    }
  }
}

// 清理结果类
class CleanupResult {
  final int totalFiles;
  final int deletedFiles;
  final int failedFiles;
  final int keptFiles;
  final String? error;

  CleanupResult({
    required this.totalFiles,
    required this.deletedFiles,
    required this.failedFiles,
    required this.keptFiles,
    this.error,
  });

  @override
  String toString() {
    return '清理结果: 总文件 $totalFiles, 已删除 $deletedFiles, 失败 $failedFiles, 保留 $keptFiles${error != null ? ", 错误: $error" : ""}';
  }
}

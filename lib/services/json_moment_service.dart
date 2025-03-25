import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import '../models/moment.dart';
import 'data_path_service.dart';
import 'path_manager.dart';

/// 使用JSON文件存储动态数据的服务
class JsonMomentService {
  static final JsonMomentService _instance = JsonMomentService._internal();
  final DataPathService _dataPathService = DataPathService();
  final List<Moment> _moments = [];
  bool _isInitialized = false;
  late String _jsonFilePath;

  // 私有构造函数
  JsonMomentService._internal();

  // 单例工厂
  factory JsonMomentService() {
    return _instance;
  }

  /// 初始化服务
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // 获取数据库目录路径
      final dbDir = await _dataPathService.getDatabasePath();
      _jsonFilePath = path.join(dbDir, 'moments.json');

      if (kDebugMode) {
        print('JSON数据文件路径: $_jsonFilePath');
      }

      // 检查JSON文件是否存在
      final jsonFile = File(_jsonFilePath);
      if (await jsonFile.exists()) {
        // 从文件读取数据
        final jsonString = await jsonFile.readAsString();
        final jsonData = jsonDecode(jsonString) as List<dynamic>;

        _moments.clear();
        for (var item in jsonData) {
          _moments.add(await _momentFromJson(item as Map<String, dynamic>));
        }

        if (kDebugMode) {
          print('成功从JSON加载了 ${_moments.length} 条动态');
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
        print('JsonMomentService初始化出错: $e');
      }
      // 出错时创建空数据
      _moments.clear();
    }
  }

  /// 保存到JSON文件
  Future<void> _saveToJson() async {
    try {
      // 确保目录存在
      final jsonFile = File(_jsonFilePath);
      final dir = Directory(path.dirname(jsonFile.path));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // 转换为JSON - 注意这里需要使用异步方法
      final jsonData = await Future.wait(_moments.map((m) => _momentToJson(m)));
      final jsonString = JsonEncoder.withIndent('  ').convert(jsonData);

      // 写入文件
      await jsonFile.writeAsString(jsonString);

      if (kDebugMode) {
        print('成功保存 ${_moments.length} 条动态到JSON文件');
      }
    } catch (e) {
      if (kDebugMode) {
        print('保存JSON数据出错: $e');
      }
    }
  }

  /// 将Moment对象转换为JSON
  Future<Map<String, dynamic>> _momentToJson(Moment moment) async {
    // 将图片路径转换为相对路径
    List<String> relativePaths = [];
    for (var imagePath in moment.imagePaths) {
      final relativePath = await PathManager.toRelativePath(imagePath);
      relativePaths.add(relativePath);
    }

    return {
      'id': moment.id,
      'content': moment.content,
      'imagePaths': relativePaths, // 使用相对路径存储
      'createTime': moment.createTime.toIso8601String(),
      'comments':
          await Future.wait(moment.comments.map((c) => _commentToJson(c))),
      'authorName': moment.authorName,
      'authorAvatar': moment.authorAvatar,
    };
  }

  /// 将Comment对象转换为JSON
  Future<Map<String, dynamic>> _commentToJson(Comment comment) async {
    return {
      'id': comment.id,
      'content': comment.content,
      'createTime': comment.createTime.toIso8601String(),
      'authorName': comment.authorName,
      'authorAvatar': comment.authorAvatar,
      'isCurrentUser': comment.isCurrentUser,
    };
  }

  /// 从JSON创建Moment对象
  Future<Moment> _momentFromJson(Map<String, dynamic> json) async {
    // 将相对路径转换为绝对路径
    List<String> absolutePaths = [];
    for (var relativePath
        in (json['imagePaths'] as List<dynamic>).cast<String>()) {
      final absolutePath = await PathManager.toAbsolutePath(relativePath);
      absolutePaths.add(absolutePath);
    }

    final commentsList = await Future.wait((json['comments'] as List<dynamic>)
        .map((c) => _commentFromJson(c as Map<String, dynamic>)));

    return Moment(
      id: json['id'] as String,
      content: json['content'] as String,
      imagePaths: absolutePaths, // 使用绝对路径
      createTime: DateTime.parse(json['createTime'] as String),
      comments: commentsList,
      authorName: json['authorName'] as String,
      authorAvatar: json['authorAvatar'] as String?,
    );
  }

  /// 从JSON创建Comment对象
  Future<Comment> _commentFromJson(Map<String, dynamic> json) async {
    return Comment(
      id: json['id'] as String,
      content: json['content'] as String,
      createTime: DateTime.parse(json['createTime'] as String),
      authorName: json['authorName'] as String,
      authorAvatar: json['authorAvatar'] as String?,
      isCurrentUser: json['isCurrentUser'] as bool? ?? false,
    );
  }

  /// 获取所有动态
  Future<List<Moment>> getAllMoments() async {
    await _ensureInitialized();
    // 返回列表副本，按时间降序排序
    return _moments.toList()
      ..sort((a, b) => b.createTime.compareTo(a.createTime));
  }

  /// 添加新动态
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

  /// 更新动态
  Future<void> updateMoment(Moment moment) async {
    await addMoment(moment); // 复用添加逻辑
  }

  /// 删除动态
  Future<void> deleteMoment(String id) async {
    await _ensureInitialized();

    // 查找要删除的动态，以获取其图片路径
    final momentIndex = _moments.indexWhere((m) => m.id == id);
    if (momentIndex < 0) {
      // 动态不存在
      return;
    }

    // 保存图片相对路径，以便后续删除
    final relativeImagePaths =
        List<String>.from(_moments[momentIndex].imagePaths);

    // 从内存中移除动态
    _moments.removeAt(momentIndex);

    // 保存到JSON
    await _saveToJson();

    // 删除关联的图片文件
    for (var relativePath in relativeImagePaths) {
      try {
        // 尝试查找和删除自定义目录下的文件
        final customRoot = await _dataPathService.getCustomRootPath();
        final absolutePathInCustom = path.join(customRoot, relativePath);

        final customFile = File(absolutePathInCustom);
        if (await customFile.exists()) {
          await customFile.delete();
          if (kDebugMode) {
            print('成功删除自定义目录下图片: $absolutePathInCustom');
          }
          continue; // 删除成功，继续下一个
        }

        // 尝试查找和删除内部存储目录下的文件
        final internalPath = await _dataPathService.getDefaultInternalPath();
        final absolutePathInInternal = path.join(internalPath, relativePath);

        final internalFile = File(absolutePathInInternal);
        if (await internalFile.exists()) {
          await internalFile.delete();
          if (kDebugMode) {
            print('成功删除内部存储目录下图片: $absolutePathInInternal');
          }
          continue; // 删除成功，继续下一个
        }

        // 尝试直接将路径作为绝对路径删除（兼容旧数据）
        final legacyFile = File(relativePath);
        if (await legacyFile.exists()) {
          await legacyFile.delete();
          if (kDebugMode) {
            print('成功删除图片(旧路径): $relativePath');
          }
        } else {
          if (kDebugMode) {
            print('图片不存在，无需删除: $relativePath');
            print('- 检查路径1: $absolutePathInCustom');
            print('- 检查路径2: $absolutePathInInternal');
            print('- 检查路径3: $relativePath');
          }
        }
      } catch (e) {
        // 图片删除失败不影响主流程
        if (kDebugMode) {
          print('删除图片失败: $relativePath, 错误: $e');
        }
      }
    }
  }

  /// 添加评论
  Future<void> addComment(String momentId, Comment comment) async {
    await _ensureInitialized();

    final momentIndex = _moments.indexWhere((m) => m.id == momentId);
    if (momentIndex >= 0) {
      _moments[momentIndex].comments.add(comment);

      // 保存到JSON
      await _saveToJson();
    }
  }

  /// 编辑评论
  Future<void> editComment(
      String momentId, String commentId, String newContent) async {
    await _ensureInitialized();

    final momentIndex = _moments.indexWhere((m) => m.id == momentId);
    if (momentIndex >= 0) {
      final commentIndex =
          _moments[momentIndex].comments.indexWhere((c) => c.id == commentId);
      if (commentIndex >= 0) {
        // 更新评论内容，保留其他属性不变
        final oldComment = _moments[momentIndex].comments[commentIndex];
        final updatedComment = Comment(
          id: oldComment.id,
          content: newContent,
          createTime: oldComment.createTime,
          authorName: oldComment.authorName,
          authorAvatar: oldComment.authorAvatar,
          isCurrentUser: oldComment.isCurrentUser,
        );

        _moments[momentIndex].comments[commentIndex] = updatedComment;

        // 保存到JSON
        await _saveToJson();
      }
    }
  }

  /// 删除评论
  Future<void> deleteComment(String momentId, String commentId) async {
    await _ensureInitialized();

    final momentIndex = _moments.indexWhere((m) => m.id == momentId);
    if (momentIndex >= 0) {
      final commentIndex =
          _moments[momentIndex].comments.indexWhere((c) => c.id == commentId);
      if (commentIndex >= 0) {
        // 移除评论
        _moments[momentIndex].comments.removeAt(commentIndex);

        // 保存到JSON
        await _saveToJson();
      }
    }
  }

  /// 确保已初始化
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await init();
    }
  }

  /// 生成唯一ID
  String generateId() {
    return const Uuid().v4();
  }

  /// 清理孤立的图片文件
  Future<CleanupResult> cleanupOrphanedImages() async {
    await _ensureInitialized();

    final imagesDir = await _dataPathService.getImagesPath();

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

/// 清理结果类
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

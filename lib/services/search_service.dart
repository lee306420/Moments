import 'dart:convert';
import 'dart:io';
import '../models/moment.dart';
import 'json_moment_service.dart';
import 'data_path_service.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart' show kDebugMode;

/// 搜索服务类 - 负责提供动态内容的搜索功能
class SearchService {
  final JsonMomentService _momentService = JsonMomentService();
  final DataPathService _dataPathService = DataPathService();
  List<String> _searchHistory = [];
  static const int _maxHistoryItems = 15; // 增加历史记录上限
  late String _historyFilePath;
  bool _isInitialized = false;

  // 缓存所有动态，提高搜索效率
  List<Moment>? _cachedMoments;
  DateTime? _lastCacheTime;
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// 初始化服务
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // 获取数据库目录路径
      final dbDir = await _dataPathService.getDatabasePath();
      _historyFilePath = path.join(dbDir, 'search_history.json');

      if (kDebugMode) {
        print('搜索历史文件路径: $_historyFilePath');
      }

      // 检查历史记录文件是否存在
      final historyFile = File(_historyFilePath);
      if (await historyFile.exists()) {
        // 从文件读取数据
        final jsonString = await historyFile.readAsString();
        final jsonData = jsonDecode(jsonString) as List<dynamic>;

        _searchHistory = jsonData.cast<String>();

        if (kDebugMode) {
          print('成功加载 ${_searchHistory.length} 条搜索历史');
        }
      } else {
        if (kDebugMode) {
          print('搜索历史文件不存在，创建新的空历史记录');
        }
        // 创建空历史记录文件
        await _saveHistory();
      }

      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) {
        print('SearchService初始化出错: $e');
      }
      // 出错时创建空历史记录
      _searchHistory = [];
    }
  }

  /// 获取搜索历史
  Future<List<String>> getSearchHistory() async {
    await _ensureInitialized();
    return _searchHistory;
  }

  /// 添加搜索词到历史记录
  Future<void> addToHistory(String query) async {
    await _ensureInitialized();

    // 不记录空查询或太短的查询
    if (query.trim().length < 2) return;

    // 移除已存在的相同查询（避免重复）
    _searchHistory.removeWhere((item) => item == query);

    // 添加到列表开头
    _searchHistory.insert(0, query);

    // 如果超出最大数量，移除最旧的
    if (_searchHistory.length > _maxHistoryItems) {
      _searchHistory = _searchHistory.sublist(0, _maxHistoryItems);
    }

    // 保存到文件
    await _saveHistory();
  }

  /// 清空搜索历史
  Future<void> clearHistory() async {
    await _ensureInitialized();
    _searchHistory.clear();
    await _saveHistory();
  }

  /// 移除单个搜索历史项
  Future<void> removeHistoryItem(String query) async {
    await _ensureInitialized();
    _searchHistory.removeWhere((item) => item == query);
    await _saveHistory();
  }

  /// 保存历史记录到文件
  Future<void> _saveHistory() async {
    try {
      // 确保目录存在
      final historyFile = File(_historyFilePath);
      final dir = Directory(path.dirname(historyFile.path));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final jsonString = JsonEncoder.withIndent('  ').convert(_searchHistory);
      await historyFile.writeAsString(jsonString);

      if (kDebugMode) {
        print('成功保存 ${_searchHistory.length} 条搜索历史');
      }
    } catch (e) {
      if (kDebugMode) {
        print('保存搜索历史出错: $e');
      }
    }
  }

  /// 确保已初始化
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await init();
    }
  }

  /// 获取所有动态，优先使用缓存
  Future<List<Moment>> _getAllMomentsWithCache() async {
    final now = DateTime.now();

    // 如果缓存有效，直接返回缓存
    if (_cachedMoments != null &&
        _lastCacheTime != null &&
        now.difference(_lastCacheTime!) < _cacheDuration) {
      if (kDebugMode) {
        print('使用缓存的动态数据，共 ${_cachedMoments!.length} 条');
      }
      return _cachedMoments!;
    }

    // 否则重新获取并缓存
    final moments = await _momentService.getAllMoments();
    _cachedMoments = moments;
    _lastCacheTime = now;

    if (kDebugMode) {
      print('重新加载动态数据，共 ${moments.length} 条');
    }

    return moments;
  }

  /// 清除缓存
  void clearCache() {
    _cachedMoments = null;
    _lastCacheTime = null;
  }

  /// 搜索动态
  /// [query] - 搜索关键词
  /// [searchInContent] - 是否搜索内容
  /// [searchInAuthor] - 是否搜索作者
  /// [searchInComments] - 是否搜索评论
  /// [sortByRelevance] - 是否按相关度排序（否则按时间）
  Future<List<Moment>> searchMoments({
    required String query,
    bool searchInContent = true,
    bool searchInAuthor = true,
    bool searchInComments = true,
    bool sortByRelevance = true,
  }) async {
    if (query.trim().isEmpty) {
      return [];
    }

    // 添加到搜索历史
    await addToHistory(query);

    final List<Moment> allMoments = await _getAllMomentsWithCache();
    final List<_SearchResult> results = [];
    final String lowerQuery = query.toLowerCase();

    // 分割搜索词以支持多词搜索
    final searchTerms =
        lowerQuery.split(' ').where((term) => term.trim().isNotEmpty).toList();

    for (var moment in allMoments) {
      int relevanceScore = 0;
      bool matchFound = false;
      final Set<String> matchTypes = {};

      // 搜索内容
      if (searchInContent) {
        final contentLower = moment.content.toLowerCase();

        // 计算每个搜索词的匹配情况
        for (var term in searchTerms) {
          if (contentLower.contains(term)) {
            matchFound = true;
            matchTypes.add('content');
            // 内容匹配给予更高权重
            relevanceScore += 3 * (contentLower.split(term).length - 1);
          }
        }

        // 完整短语匹配额外加分
        if (contentLower.contains(lowerQuery)) {
          relevanceScore += 5;
        }
      }

      // 搜索作者
      if (searchInAuthor) {
        final authorLower = moment.authorName.toLowerCase();

        for (var term in searchTerms) {
          if (authorLower.contains(term)) {
            matchFound = true;
            matchTypes.add('author');
            // 作者匹配
            relevanceScore += 2;
          }
        }

        // 完整作者名匹配额外加分
        if (authorLower.contains(lowerQuery)) {
          relevanceScore += 3;
        }
      }

      // 搜索评论
      if (searchInComments) {
        int commentMatches = 0;

        for (var comment in moment.comments) {
          final commentLower = comment.content.toLowerCase();
          final authorLower = comment.authorName.toLowerCase();
          bool thisCommentMatches = false;

          // 检查每个搜索词
          for (var term in searchTerms) {
            if (commentLower.contains(term) || authorLower.contains(term)) {
              thisCommentMatches = true;
              break;
            }
          }

          if (thisCommentMatches) {
            commentMatches++;
          }
        }

        if (commentMatches > 0) {
          matchFound = true;
          matchTypes.add('comments');
          // 评论匹配，根据匹配的评论数量增加分数
          relevanceScore += commentMatches;
        }
      }

      if (matchFound) {
        // 额外考虑动态的新鲜度
        final ageInDays = DateTime.now().difference(moment.createTime).inDays;
        final freshnessScore = ageInDays < 7 ? (7 - ageInDays) : 0;

        // 最终分数 = 相关度分数 + 新鲜度加分
        final finalScore = relevanceScore + freshnessScore;

        results.add(_SearchResult(
          moment: moment,
          relevanceScore: finalScore,
          matchTypes: matchTypes,
        ));
      }
    }

    // 根据指定的排序方式进行排序
    if (sortByRelevance) {
      // 按相关度降序排序
      results.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
    } else {
      // 按时间降序排序
      results
          .sort((a, b) => b.moment.createTime.compareTo(a.moment.createTime));
    }

    return results.map((r) => r.moment).toList();
  }
}

/// 内部使用的搜索结果类，用于排序和相关度计算
class _SearchResult {
  final Moment moment;
  final int relevanceScore;
  final Set<String> matchTypes;

  _SearchResult({
    required this.moment,
    required this.relevanceScore,
    required this.matchTypes,
  });
}

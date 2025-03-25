import 'dart:io';
import 'package:flutter/material.dart';
import '../models/moment.dart';
import '../services/json_moment_service.dart';

class MomentProvider extends ChangeNotifier {
  final JsonMomentService _momentService = JsonMomentService();
  List<Moment> _moments = [];
  List<Moment> _filteredMoments = [];
  bool _isLoading = false;
  DateTime? _selectedDate;
  DateTime? _selectedMonth;
  bool _isFiltering = false;
  bool _isMonthFiltering = false;

  List<Moment> get moments => _isFiltering
      ? _filteredMoments
      : _isMonthFiltering
          ? _filteredMoments
          : _moments;
  bool get isLoading => _isLoading;
  DateTime? get selectedDate => _selectedDate;
  DateTime? get selectedMonth => _selectedMonth;
  bool get isFiltering => _isFiltering;
  bool get isMonthFiltering => _isMonthFiltering;

  Future<void> loadMoments() async {
    _isLoading = true;
    notifyListeners();

    _moments = await _momentService.getAllMoments();

    // 如果正在筛选，更新筛选后的结果
    if (_isFiltering && _selectedDate != null) {
      _applyDateFilter(_selectedDate!);
    } else if (_isMonthFiltering && _selectedMonth != null) {
      _applyMonthFilter(_selectedMonth!);
    } else {
      _isFiltering = false;
      _isMonthFiltering = false;
      _filteredMoments = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  // 按日期筛选动态
  void filterByDate(DateTime? date) {
    if (date == null) {
      // 清除筛选
      _isFiltering = false;
      _selectedDate = null;
      _filteredMoments = [];
      notifyListeners();
      return;
    }

    // 清除月份筛选
    _isMonthFiltering = false;
    _selectedMonth = null;

    _selectedDate = date;
    _isFiltering = true;
    _applyDateFilter(date);
    notifyListeners();
  }

  // 按月份筛选动态
  void filterByMonth(DateTime? month) {
    if (month == null) {
      // 清除筛选
      _isMonthFiltering = false;
      _selectedMonth = null;
      _filteredMoments = [];
      notifyListeners();
      return;
    }

    // 清除日期筛选
    _isFiltering = false;
    _selectedDate = null;

    _selectedMonth = month;
    _isMonthFiltering = true;
    _applyMonthFilter(month);
    notifyListeners();
  }

  // 应用日期筛选
  void _applyDateFilter(DateTime date) {
    // 获取所选日期的年、月、日
    final year = date.year;
    final month = date.month;
    final day = date.day;

    // 筛选出同一天的动态
    _filteredMoments = _moments.where((moment) {
      final momentDate = moment.createTime;
      return momentDate.year == year &&
          momentDate.month == month &&
          momentDate.day == day;
    }).toList();
  }

  // 应用月份筛选
  void _applyMonthFilter(DateTime month) {
    // 获取所选月份的年、月
    final year = month.year;
    final monthNum = month.month;

    // 筛选出同一月的动态
    _filteredMoments = _moments.where((moment) {
      final momentDate = moment.createTime;
      return momentDate.year == year && momentDate.month == monthNum;
    }).toList();
  }

  // 清除日期筛选
  void clearDateFilter() {
    _isFiltering = false;
    _selectedDate = null;
    _filteredMoments = [];
    notifyListeners();
  }

  // 清除月份筛选
  void clearMonthFilter() {
    _isMonthFiltering = false;
    _selectedMonth = null;
    _filteredMoments = [];
    notifyListeners();
  }

  // 清除所有筛选
  void clearAllFilters() {
    _isFiltering = false;
    _isMonthFiltering = false;
    _selectedDate = null;
    _selectedMonth = null;
    _filteredMoments = [];
    notifyListeners();
  }

  Future<void> addMoment({
    required String content,
    required List<String> imagePaths,
    required String authorName,
    String? authorAvatar,
  }) async {
    final newMoment = Moment(
      id: _momentService.generateId(),
      content: content,
      imagePaths: imagePaths,
      createTime: DateTime.now(),
      authorName: authorName,
      authorAvatar: authorAvatar,
    );

    await _momentService.addMoment(newMoment);
    await loadMoments(); // 重新加载数据
  }

  Future<void> editMoment({
    required String momentId,
    required String content,
    List<String>? imagePaths,
  }) async {
    // 查找要编辑的动态
    final momentIndex = _moments.indexWhere((m) => m.id == momentId);
    if (momentIndex < 0) {
      return; // 动态不存在
    }

    // 获取原有动态
    final originalMoment = _moments[momentIndex];

    // 创建更新后的动态，只更新内容和图片（如果提供），保留其他属性
    final updatedMoment = Moment(
      id: originalMoment.id,
      content: content,
      imagePaths: imagePaths ?? originalMoment.imagePaths,
      createTime: originalMoment.createTime,
      comments: originalMoment.comments,
      authorName: originalMoment.authorName,
      authorAvatar: originalMoment.authorAvatar,
    );

    // 更新动态
    await _momentService.updateMoment(updatedMoment);
    await loadMoments(); // 重新加载数据
  }

  Future<void> addComment({
    required String momentId,
    required String content,
    required String authorName,
    String? authorAvatar,
  }) async {
    final comment = Comment(
      id: _momentService.generateId(),
      content: content,
      createTime: DateTime.now(),
      authorName: authorName,
      authorAvatar: authorAvatar,
      isCurrentUser: true, // 标记为当前用户发布的评论
    );

    await _momentService.addComment(momentId, comment);
    await loadMoments(); // 重新加载数据
  }

  Future<void> editComment({
    required String momentId,
    required String commentId,
    required String newContent,
  }) async {
    await _momentService.editComment(momentId, commentId, newContent);
    await loadMoments(); // 重新加载数据
  }

  Future<void> deleteComment({
    required String momentId,
    required String commentId,
  }) async {
    await _momentService.deleteComment(momentId, commentId);
    await loadMoments(); // 重新加载数据
  }

  Future<void> deleteMoment(String momentId) async {
    await _momentService.deleteMoment(momentId);
    await loadMoments(); // 重新加载数据
  }
}

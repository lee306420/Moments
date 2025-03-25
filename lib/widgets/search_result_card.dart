import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/moment.dart';
import '../screens/moment_detail_screen.dart';
import 'highlighted_text.dart';
import 'dart:math' as math;

class SearchResultCard extends StatelessWidget {
  final Moment moment;
  final String searchQuery;

  const SearchResultCard({
    Key? key,
    required this.moment,
    required this.searchQuery,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => MomentDetailScreen(momentId: moment.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 8),
              if (moment.content.isNotEmpty) ...[
                _buildContent(context),
                const SizedBox(height: 8),
              ],
              if (moment.imagePaths.isNotEmpty) ...[
                _buildImagePreview(),
                const SizedBox(height: 8),
              ],
              _buildMatchInfo(context),
              const SizedBox(height: 2),
              _buildBottomInfo(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundImage: moment.authorAvatar != null
              ? FileImage(File(moment.authorAvatar!))
              : null,
          child: moment.authorAvatar == null
              ? Text(moment.authorName.isNotEmpty
                  ? moment.authorName[0].toUpperCase()
                  : '?')
              : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                moment.authorName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                children: [
                  Text(
                    DateFormat('yyyy-MM-dd HH:mm').format(moment.createTime),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getRelativeTime(moment.createTime),
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    return HighlightedText(
      text: moment.content,
      highlightText: searchQuery,
      style: const TextStyle(fontSize: 16),
      maxLines: 5,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildImagePreview() {
    if (moment.imagePaths.isEmpty) return const SizedBox();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (int i = 0; i < math.min(3, moment.imagePaths.length); i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildImageThumbnail(moment.imagePaths[i], i),
            ),
          if (moment.imagePaths.length > 3)
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '+${moment.imagePaths.length - 3}',
                  style: TextStyle(
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageThumbnail(String imagePath, int index) {
    final file = File(imagePath);

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade200,
      ),
      child: file.existsSync()
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                file,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.broken_image, color: Colors.red);
                },
              ),
            )
          : const Icon(Icons.broken_image, color: Colors.red),
    );
  }

  Widget _buildMatchInfo(BuildContext context) {
    final matchTypes = _getMatchTypes();

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (var type in matchTypes) _buildMatchChip(type),
      ],
    );
  }

  Widget _buildMatchChip(String type) {
    IconData chipIcon;
    Color chipColor;
    String chipLabel;

    switch (type) {
      case 'content':
        chipIcon = Icons.subject;
        chipColor = Colors.blue;
        chipLabel = '内容匹配';
        break;
      case 'comments':
        chipIcon = Icons.comment;
        chipColor = Colors.orange;
        final count = _getMatchingCommentsCount();
        chipLabel = '$count条评论匹配';
        break;
      default:
        chipIcon = Icons.search;
        chipColor = Colors.purple;
        chipLabel = '匹配';
    }

    return Chip(
      avatar: Icon(chipIcon, size: 16, color: Colors.white),
      label: Text(chipLabel),
      backgroundColor: chipColor,
      labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 2),
    );
  }

  Widget _buildBottomInfo(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.comment, size: 16, color: Colors.blue.shade300),
            const SizedBox(width: 4),
            Text(
              '${moment.comments.length}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      ],
    );
  }

  /// 获取匹配的类型列表
  List<String> _getMatchTypes() {
    final List<String> matchTypes = [];
    final String lowerQuery = searchQuery.toLowerCase();
    final List<String> keywords = lowerQuery
        .split(' ')
        .where((keyword) => keyword.trim().isNotEmpty)
        .toList();

    // 检查内容匹配
    bool contentMatch = false;
    final String lowerContent = moment.content.toLowerCase();

    for (var keyword in keywords) {
      if (lowerContent.contains(keyword)) {
        contentMatch = true;
        break;
      }
    }

    if (contentMatch) {
      matchTypes.add('content');
    }

    // 检查评论匹配
    if (_getMatchingCommentsCount() > 0) {
      matchTypes.add('comments');
    }

    return matchTypes;
  }

  /// 获取匹配的评论数量
  int _getMatchingCommentsCount() {
    final String lowerQuery = searchQuery.toLowerCase();
    final List<String> keywords = lowerQuery
        .split(' ')
        .where((keyword) => keyword.trim().isNotEmpty)
        .toList();

    int count = 0;

    for (var comment in moment.comments) {
      final String lowerContent = comment.content.toLowerCase();
      final String lowerAuthor = comment.authorName.toLowerCase();
      bool matches = false;

      for (var keyword in keywords) {
        if (lowerContent.contains(keyword) || lowerAuthor.contains(keyword)) {
          matches = true;
          break;
        }
      }

      if (matches) {
        count++;
      }
    }

    return count;
  }

  /// 获取相对时间文本 (例如: "3天前")
  String _getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return '刚刚';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}小时前';
    } else if (difference.inDays < 30) {
      return '${difference.inDays}天前';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()}个月前';
    } else {
      return '${(difference.inDays / 365).floor()}年前';
    }
  }
}

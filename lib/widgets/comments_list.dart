import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/moment.dart';
import '../main.dart'; // 导入主题

typedef CommentEditCallback = Future<void> Function(
    String commentId, String newContent);
typedef CommentDeleteCallback = Future<void> Function(String commentId);

class CommentsList extends StatelessWidget {
  final List<Comment> comments;
  final CommentEditCallback? onEdit;
  final CommentDeleteCallback? onDelete;
  final String? momentId;

  const CommentsList({
    super.key,
    required this.comments,
    this.onEdit,
    this.onDelete,
    this.momentId,
  });

  @override
  Widget build(BuildContext context) {
    if (comments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 48,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 12),
              Text(
                '暂无评论',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '成为第一个评论的人吧',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: comments.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        color: Colors.grey.shade200,
        indent: 68,
      ),
      itemBuilder: (context, index) {
        final comment = comments[index];

        // 只有用户自己的评论才可以左滑操作
        if (comment.isCurrentUser) {
          return _buildDismissibleCommentItem(context, comment);
        } else {
          return _buildCommentItem(comment);
        }
      },
    );
  }

  // 构建可左滑的评论项
  Widget _buildDismissibleCommentItem(BuildContext context, Comment comment) {
    return Dismissible(
      key: Key(comment.id),
      background: Container(
        color: AppTheme.secondaryColor,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Row(
          children: [
            Icon(Icons.edit, color: Colors.white),
            SizedBox(width: 8),
            Text('编辑',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      secondaryBackground: Container(
        color: AppTheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('删除',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            SizedBox(width: 8),
            Icon(Icons.delete, color: Colors.white),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // 编辑操作
          _showEditDialog(context, comment);
          return false; // 不真正删除列表项
        } else {
          // 删除操作
          return await _showDeleteConfirmationDialog(context);
        }
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart && onDelete != null) {
          onDelete!(comment.id);
        }
      },
      child: _buildCommentItem(comment),
    );
  }

  // 构建普通评论项
  Widget _buildCommentItem(Comment comment) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: comment.isCurrentUser
                ? AppTheme.primaryColor
                : Colors.grey.shade200,
            backgroundImage: comment.authorAvatar != null
                ? FileImage(File(comment.authorAvatar!))
                : null,
            child: comment.authorAvatar == null
                ? Text(
                    comment.authorName.isNotEmpty
                        ? comment.authorName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: comment.isCurrentUser ? Colors.white : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.authorName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: comment.isCurrentUser
                            ? AppTheme.primaryColor
                            : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (comment.isCurrentUser)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: const Text(
                          '我',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    Expanded(child: Container()),
                    Text(
                      DateFormat('MM-dd HH:mm').format(comment.createTime),
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.content,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.3,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, Comment comment) {
    final TextEditingController controller =
        TextEditingController(text: comment.content);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        ),
        title: Row(
          children: [
            const Icon(Icons.edit, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            const Text('编辑评论'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '修改您的评论内容：',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppTheme.smallBorderRadius),
                ),
                hintText: '编辑你的评论...',
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty &&
                  onEdit != null &&
                  momentId != null) {
                Navigator.of(context).pop();
                await onEdit!(comment.id, controller.text.trim());
              } else if (controller.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('评论内容不能为空'),
                    backgroundColor: AppTheme.error,
                  ),
                );
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  // 显示删除确认对话框，返回用户是否确认删除
  Future<bool> _showDeleteConfirmationDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
            ),
            title: Row(
              children: [
                const Icon(Icons.delete, color: AppTheme.error),
                const SizedBox(width: 8),
                const Text('删除评论'),
              ],
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('确定要删除这条评论吗？此操作不可撤销。'),
                SizedBox(height: 12),
                Text(
                  '删除后，评论将立即从动态中移除。',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

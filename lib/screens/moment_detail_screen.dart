import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/moment.dart';
import '../providers/moment_provider.dart';
import '../widgets/comments_list.dart';
import '../utils/path_display_util.dart'; // 导入路径显示工具
import '../screens/photo_preview_screen.dart'; // 导入照片预览页面
import '../main.dart'; // 导入主题
import 'edit_moment_screen.dart'; // 导入动态编辑页面

class MomentDetailScreen extends StatefulWidget {
  final String momentId;

  const MomentDetailScreen({super.key, required this.momentId});

  @override
  State<MomentDetailScreen> createState() => _MomentDetailScreenState();
}

class _MomentDetailScreenState extends State<MomentDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  bool _isPostingComment = false;

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  void _addComment(Moment moment) async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() {
      _isPostingComment = true;
    });

    try {
      await Provider.of<MomentProvider>(context, listen: false).addComment(
        momentId: moment.id,
        content: _commentController.text.trim(),
        authorName: '我', // 实际应用中应获取真实用户信息
      );

      _commentController.clear();
      // 隐藏键盘
      FocusScope.of(context).unfocus();
    } finally {
      setState(() {
        _isPostingComment = false;
      });
    }
  }

  void _showPathInfo(List<String> imagePaths) {
    PathDisplayUtil.showSavePathInfo(context, imagePaths);
  }

  // 跳转到编辑动态页面
  void _navigateToEditScreen(Moment moment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditMomentScreen(moment: moment),
      ),
    );
  }

  // 显示删除确认对话框
  void _showDeleteConfirmation(Moment moment) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        ),
        title: Row(
          children: [
            const Icon(Icons.delete, color: AppTheme.error),
            const SizedBox(width: 8),
            const Text('删除动态'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('确定要删除这条动态吗？此操作不可撤销。'),
            SizedBox(height: 12),
            Text(
              '删除后，动态及其所有评论将被永久移除。',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
            ),
            onPressed: () {
              Provider.of<MomentProvider>(context, listen: false)
                  .deleteMoment(moment.id);
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(); // 返回动态列表页
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('动态详情'),
        elevation: 0,
        actions: [
          Consumer<MomentProvider>(
            builder: (ctx, provider, _) {
              final moment = provider.moments.firstWhere(
                (m) => m.id == widget.momentId,
                orElse: () => Moment(
                  id: '',
                  content: '',
                  imagePaths: [],
                  createTime: DateTime.now(),
                  authorName: '',
                ),
              );

              if (moment.id.isEmpty) return const SizedBox.shrink();

              return PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppTheme.smallBorderRadius),
                ),
                onSelected: (value) {
                  if (value == 'edit') {
                    _navigateToEditScreen(moment);
                  } else if (value == 'delete') {
                    _showDeleteConfirmation(moment);
                  } else if (value == 'path_info') {
                    _showPathInfo(moment.imagePaths);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, color: AppTheme.secondaryColor),
                        SizedBox(width: 8),
                        Text('编辑动态'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: AppTheme.error),
                        SizedBox(width: 8),
                        Text('删除动态'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'path_info',
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: AppTheme.primaryColor),
                        SizedBox(width: 8),
                        Text('查看路径信息'),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<MomentProvider>(
        builder: (ctx, provider, _) {
          final moment = provider.moments.firstWhere(
            (m) => m.id == widget.momentId,
            orElse: () => Moment(
              id: '',
              content: '',
              imagePaths: [],
              createTime: DateTime.now(),
              authorName: '',
            ),
          );

          if (moment.id.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    '动态不存在或已被删除',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // 动态内容部分
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 头部信息
                      Card(
                        margin: const EdgeInsets.all(16.0),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.borderRadius),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Hero(
                                tag: 'avatar_${moment.id}',
                                child: CircleAvatar(
                                  radius: 24,
                                  backgroundImage: moment.authorAvatar != null
                                      ? FileImage(File(moment.authorAvatar!))
                                      : null,
                                  child: moment.authorAvatar == null
                                      ? Text(
                                          moment.authorName.isNotEmpty
                                              ? moment.authorName[0]
                                                  .toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : null,
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      moment.authorName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.access_time,
                                          size: 14,
                                          color: AppTheme.textSecondary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          DateFormat('yyyy-MM-dd HH:mm')
                                              .format(moment.createTime),
                                          style: const TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // 文字内容
                      Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16.0),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.borderRadius),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            moment.content,
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),

                      // 图片内容
                      if (moment.imagePaths.isNotEmpty)
                        Card(
                          margin: const EdgeInsets.all(16.0),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.borderRadius),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: _buildImages(moment),
                          ),
                        ),

                      // 评论分割线和标题
                      Container(
                        margin: const EdgeInsets.only(top: 16.0),
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: AppTheme.scaffoldBackground,
                          border: Border(
                            top: BorderSide(
                              color: AppTheme.dividerColor,
                              width: 1,
                            ),
                            bottom: BorderSide(
                              color: AppTheme.dividerColor,
                              width: 1,
                            ),
                          ),
                        ),
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.chat_bubble_outline,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '评论 (${moment.comments.length})',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 评论列表
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.borderRadius),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: CommentsList(
                              comments: moment.comments,
                              momentId: moment.id,
                              onEdit: (commentId, newContent) async {
                                await Provider.of<MomentProvider>(context,
                                        listen: false)
                                    .editComment(
                                  momentId: moment.id,
                                  commentId: commentId,
                                  newContent: newContent,
                                );
                              },
                              onDelete: (commentId) async {
                                await Provider.of<MomentProvider>(context,
                                        listen: false)
                                    .deleteComment(
                                  momentId: moment.id,
                                  commentId: commentId,
                                );
                              },
                            ),
                          ),
                        ),
                      ),

                      // 底部额外空间
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),

              // 评论输入框
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: const Offset(0, -1),
                    ),
                  ],
                ),
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 10,
                  bottom: 10,
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            color: Colors.grey.shade50,
                            border: Border.all(
                              color: AppTheme.dividerColor,
                              width: 1,
                            ),
                          ),
                          child: TextField(
                            controller: _commentController,
                            focusNode: _commentFocusNode,
                            decoration: InputDecoration(
                              hintText: '写下你的评论...',
                              hintStyle: TextStyle(
                                color: Colors.grey.shade400,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              isDense: true,
                            ),
                            maxLines: 1,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: _isPostingComment
                            ? Colors.grey.shade200
                            : AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(50),
                        child: _isPostingComment
                            ? const Padding(
                                padding: EdgeInsets.all(10),
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        AppTheme.primaryColor),
                                  ),
                                ),
                              )
                            : InkWell(
                                onTap: () => _addComment(moment),
                                borderRadius: BorderRadius.circular(50),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  child: const Icon(
                                    Icons.send,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildImages(Moment moment) {
    if (moment.imagePaths.isEmpty) return const SizedBox.shrink();

    if (moment.imagePaths.length == 1) {
      return Hero(
        tag: 'image_${moment.id}_0',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
          child: GestureDetector(
            onTap: () => _showFullScreenImage(context, moment.imagePaths[0]),
            child: Image.file(
              File(moment.imagePaths[0]),
              fit: BoxFit.cover,
              height: 250,
              width: double.infinity,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 250,
                  width: double.infinity,
                  color: Colors.grey.shade200,
                  alignment: Alignment.center,
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('图片加载失败', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    return StaggeredGrid.count(
      crossAxisCount: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: List.generate(moment.imagePaths.length, (index) {
        final path = moment.imagePaths[index];
        return StaggeredGridTile.count(
          crossAxisCellCount: 1,
          mainAxisCellCount: 1,
          child: Hero(
            tag: 'image_${moment.id}_$index',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
              child: GestureDetector(
                onTap: () => _showFullScreenImage(context, path),
                child: Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey.shade200,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.broken_image,
                        size: 24,
                        color: Colors.grey,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  void _showFullScreenImage(BuildContext context, String imagePath) {
    // 找到该路径在列表中的索引
    final moment = Provider.of<MomentProvider>(context, listen: false)
        .moments
        .firstWhere((m) => m.id == widget.momentId);

    final int index = moment.imagePaths.indexOf(imagePath);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => PhotoPreviewScreen(
          imagePaths: moment.imagePaths,
          initialIndex: index,
          heroTag: 'image_${moment.id}_$index',
        ),
      ),
    );
  }
}

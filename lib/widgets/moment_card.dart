import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/moment.dart';
import '../providers/moment_provider.dart';
import '../screens/moment_detail_screen.dart';
import '../screens/photo_preview_screen.dart';
import '../utils/path_display_util.dart';

class MomentCard extends StatelessWidget {
  final Moment moment;

  const MomentCard({super.key, required this.moment});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => MomentDetailScreen(momentId: moment.id),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        elevation: 0.5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 8),
              if (moment.content.isNotEmpty) ...[
                _buildContent(),
                const SizedBox(height: 8),
              ],
              if (moment.imagePaths.isNotEmpty) ...[
                _buildImages(context),
                const SizedBox(height: 8),
              ],
              _buildFooter(context),
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
          radius: 20,
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
              ),
              Text(
                DateFormat('yyyy-MM-dd HH:mm').format(moment.createTime),
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    return Text(
      moment.content,
      style: const TextStyle(fontSize: 16),
    );
  }

  Widget _buildImages(BuildContext context) {
    return _buildImagesGrid(context);
  }

  Widget _buildImagesGrid(BuildContext context) {
    final imagePaths = moment.imagePaths;
    if (imagePaths.isEmpty) return const SizedBox();

    // 验证图片是否存在，如果不存在则显示错误提示
    List<Widget> imageWidgets = [];
    for (var imagePath in imagePaths) {
      final file = File(imagePath);
      if (!file.existsSync()) {
        if (kDebugMode) {
          print('图片文件不存在: $imagePath');
        }
        // 添加一个错误占位图
        imageWidgets.add(
          GestureDetector(
            onTap: () {
              PathDisplayUtil.showSavePathInfo(context, [imagePath]);
            },
            child: Container(
              color: Colors.grey[300],
              child: const Center(
                child: Icon(
                  Icons.broken_image,
                  color: Colors.red,
                  size: 40,
                ),
              ),
            ),
          ),
        );
      } else {
        // 添加正常图片
        imageWidgets.add(
          GestureDetector(
            onTap: () {
              _showFullScreenImage(context, imagePath);
            },
            child: Image.file(
              file,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[200],
                  child: const Center(
                    child: Icon(Icons.error, color: Colors.red),
                  ),
                );
              },
            ),
          ),
        );
      }
    }

    // 根据图片数量决定布局
    if (imagePaths.length == 1) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: imageWidgets[0],
      );
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: imagePaths.length == 2 ? 2 : 3,
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      children: imageWidgets,
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.comment_outlined),
              onPressed: () {
                // 跳转到详情页面，而不是直接显示评论对话框
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => MomentDetailScreen(momentId: moment.id),
                  ),
                );
              },
            ),
            InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => MomentDetailScreen(momentId: moment.id),
                  ),
                );
              },
              child: Text('${moment.comments.length}'),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.favorite_border),
              onPressed: () {
                Provider.of<MomentProvider>(context, listen: false)
                    .likeMoment(moment.id);
              },
            ),
            Text('${moment.likes}'),
          ],
        ),
      ],
    );
  }

  void _showCommentDialog(BuildContext context) {
    final TextEditingController commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('发表评论'),
        content: TextField(
          controller: commentController,
          decoration: const InputDecoration(
            hintText: '写下你的评论...',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              if (commentController.text.trim().isNotEmpty) {
                Provider.of<MomentProvider>(context, listen: false).addComment(
                  momentId: moment.id,
                  content: commentController.text.trim(),
                  authorName: '我', // 这里应该用实际用户名
                );
                Navigator.of(context).pop();
              }
            },
            child: const Text('发布'),
          ),
        ],
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, String imagePath) {
    final int index = moment.imagePaths.indexOf(imagePath);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => PhotoPreviewScreen(
          imagePaths: moment.imagePaths,
          initialIndex: index,
          heroTag: 'moment_${moment.id}',
        ),
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/moment_provider.dart';
import '../utils/image_utils.dart';
import '../utils/path_display_util.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class NewMomentScreen extends StatefulWidget {
  const NewMomentScreen({super.key});

  @override
  State<NewMomentScreen> createState() => _NewMomentScreenState();
}

class _NewMomentScreenState extends State<NewMomentScreen> {
  final TextEditingController _contentController = TextEditingController();
  final List<File> _selectedImages = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final pickedImages = await ImageUtils.pickImages();
    if (pickedImages.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(pickedImages);
      });
    }
  }

  Future<void> _takePhoto() async {
    final photo = await ImageUtils.takePhoto();
    if (photo != null) {
      setState(() {
        _selectedImages.add(photo);
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _publishMoment() async {
    if (_isLoading) return;

    // 检查是否有内容
    if (_selectedImages.isEmpty && _contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请添加图片或输入内容')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 保存图片
      List<String> imagePaths = [];
      if (_selectedImages.isNotEmpty) {
        // 获取图片目录
        for (var image in _selectedImages) {
          final savedPath = await ImageUtils.saveImageToLocal(image);
          if (savedPath != null) {
            imagePaths.add(savedPath);
          }
        }
      }

      // 发布动态
      await Provider.of<MomentProvider>(context, listen: false).addMoment(
        content: _contentController.text,
        imagePaths: imagePaths,
        authorName: '我', // 这里应该用实际用户名
      );

      if (kDebugMode) {
        print('发布成功: ${imagePaths.length} 张图片');
      }

      // 提示保存成功
      if (mounted) {
        // 展示保存路径信息
        PathDisplayUtil.showSavePathInfo(context, imagePaths);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('发布成功')),
        );

        // 返回上一页
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (kDebugMode) {
        print('发布失败: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发布失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '发布动态',
          style: TextStyle(
            color: Colors.black,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : TextButton(
                  onPressed: _publishMoment,
                  child: const Text(
                    '发布',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _contentController,
                decoration: const InputDecoration(
                  hintText: '这一刻的想法...',
                  border: InputBorder.none,
                ),
                maxLines: 5,
                maxLength: 140,
              ),
              const SizedBox(height: 16),
              if (_selectedImages.isNotEmpty) ...[
                const Text('已选择的图片:'),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _selectedImages.length,
                  itemBuilder: (ctx, index) {
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            _selectedImages[index],
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: InkWell(
                            onTap: () => _removeImage(index),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.photo_library),
                    onPressed: _pickImages,
                  ),
                  IconButton(
                    icon: const Icon(Icons.photo_camera),
                    onPressed: _takePhoto,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

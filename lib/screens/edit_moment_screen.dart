import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import '../models/moment.dart';
import '../providers/moment_provider.dart';
import '../main.dart';
import '../utils/image_utils.dart';

class EditMomentScreen extends StatefulWidget {
  final Moment moment;

  const EditMomentScreen({super.key, required this.moment});

  @override
  State<EditMomentScreen> createState() => _EditMomentScreenState();
}

class _EditMomentScreenState extends State<EditMomentScreen> {
  late TextEditingController _contentController;
  List<String> _imagePaths = [];
  bool _isSubmitting = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.moment.content);
    _contentController.addListener(_checkForChanges);
    _imagePaths = List.from(widget.moment.imagePaths);
  }

  @override
  void dispose() {
    _contentController.removeListener(_checkForChanges);
    _contentController.dispose();
    super.dispose();
  }

  void _checkForChanges() {
    final contentChanged = _contentController.text != widget.moment.content;

    // 检查图片数量或顺序是否有变化
    bool imagesChanged = _imagePaths.length != widget.moment.imagePaths.length;

    // 如果数量相同，检查顺序是否有变化
    if (!imagesChanged && _imagePaths.isNotEmpty) {
      for (int i = 0; i < _imagePaths.length; i++) {
        if (_imagePaths[i] != widget.moment.imagePaths[i]) {
          imagesChanged = true;
          break;
        }
      }
    }

    setState(() {
      _hasChanges = contentChanged || imagesChanged;
    });
  }

  Future<void> _saveMoment() async {
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('动态内容不能为空'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // 保存编辑后的动态
      await Provider.of<MomentProvider>(context, listen: false).editMoment(
        momentId: widget.moment.id,
        content: _contentController.text.trim(),
        imagePaths: _imagePaths,
      );

      // 成功保存后关闭页面
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('动态更新成功'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        // 保存图片到应用存储
        final savedImagePath = await ImageUtils.saveImageToLocal(
          File(pickedFile.path),
        );

        setState(() {
          _imagePaths.add(savedImagePath);
          _checkForChanges();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('选择图片失败: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  void _removeImage(int index) {
    setState(() {
      _imagePaths.removeAt(index);
      _checkForChanges();
    });
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    // 有未保存的更改，显示确认对话框
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.amber),
            SizedBox(width: 8),
            Text('未保存的更改'),
          ],
        ),
        content: const Text('你有未保存的更改，确定要放弃这些更改吗？'),
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
            child: const Text('放弃更改'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('编辑动态'),
          elevation: 0,
          actions: [
            if (_hasChanges)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: _isSubmitting
                    ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                AppTheme.primaryColor),
                          ),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.check),
                        onPressed: _saveMoment,
                        tooltip: '保存',
                      ),
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 内容编辑框
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _contentController,
                    maxLines: 8,
                    maxLength: 500,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                    ),
                    decoration: const InputDecoration(
                      hintText: '说点什么...',
                      border: InputBorder.none,
                      counter: SizedBox.shrink(),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 已选图片
              if (_imagePaths.isNotEmpty)
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '图片',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '拖拽可调整顺序',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ReorderableGridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1,
                          ),
                          itemCount: _imagePaths.length,
                          itemBuilder: (context, index) {
                            return Stack(
                              key: ValueKey(_imagePaths[index]),
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                      AppTheme.smallBorderRadius),
                                  child: Image.file(
                                    File(_imagePaths[index]),
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () => _removeImage(index),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.6),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 4,
                                  top: 4,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.drag_indicator,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                          onReorder: (oldIndex, newIndex) {
                            // 提供触觉反馈
                            HapticFeedback.mediumImpact();

                            setState(() {
                              if (oldIndex < newIndex) {
                                newIndex -= 1;
                              }
                              final item = _imagePaths.removeAt(oldIndex);
                              _imagePaths.insert(newIndex, item);
                              _checkForChanges();
                            });
                          },
                          dragWidgetBuilder: (index, child) {
                            return Container(
                              decoration: BoxDecoration(
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: child,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // 添加图片按钮
              if (_imagePaths.length < 9)
                Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add_photo_alternate),
                    label: const Text('添加图片'),
                    onPressed: _pickImage,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

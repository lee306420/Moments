import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as path;

/// 照片预览页面 - 仿原生相册效果
class PhotoPreviewScreen extends StatefulWidget {
  final List<String> imagePaths;
  final int initialIndex;
  final String? heroTag;

  const PhotoPreviewScreen({
    Key? key,
    required this.imagePaths,
    this.initialIndex = 0,
    this.heroTag,
  }) : super(key: key);

  @override
  _PhotoPreviewScreenState createState() => _PhotoPreviewScreenState();
}

class _PhotoPreviewScreenState extends State<PhotoPreviewScreen> {
  late int _currentIndex;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () => _shareImage(),
          ),
        ],
      ),
      body: Stack(
        children: [
          PhotoViewGallery.builder(
            scrollPhysics: const BouncingScrollPhysics(),
            builder: _buildItem,
            itemCount: widget.imagePaths.length,
            loadingBuilder: (context, event) => const Center(
              child: CircularProgressIndicator(),
            ),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            pageController: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
          ),
          Positioned(
            bottom: 16.0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.imagePaths.length > 1)
                    Text(
                      '${_currentIndex + 1}/${widget.imagePaths.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16.0,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  PhotoViewGalleryPageOptions _buildItem(BuildContext context, int index) {
    final String imagePath = widget.imagePaths[index];
    final File imageFile = File(imagePath);

    return PhotoViewGalleryPageOptions(
      imageProvider: FileImage(imageFile),
      initialScale: PhotoViewComputedScale.contained,
      minScale: PhotoViewComputedScale.contained * 0.8,
      maxScale: PhotoViewComputedScale.covered * 2,
      heroAttributes: widget.heroTag != null
          ? PhotoViewHeroAttributes(tag: '${widget.heroTag}_$index')
          : null,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.black,
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image, color: Colors.white, size: 48),
                SizedBox(height: 16),
                Text(
                  '无法加载图片',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _shareImage() {
    if (_currentIndex >= 0 && _currentIndex < widget.imagePaths.length) {
      final filePath = widget.imagePaths[_currentIndex];

      Share.shareFiles(
        [filePath],
        text: '分享图片: ${path.basename(filePath)}',
      ).catchError((error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败: $error')),
        );
      });
    }
  }
}

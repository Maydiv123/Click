import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class ImageGalleryViewScreen extends StatefulWidget {
  final List<File> images;
  final int initialIndex;

  const ImageGalleryViewScreen({
    Key? key,
    required this.images,
    required this.initialIndex,
  }) : super(key: key);

  @override
  State<ImageGalleryViewScreen> createState() => _ImageGalleryViewScreenState();
}

class _ImageGalleryViewScreenState extends State<ImageGalleryViewScreen> {
  late PageController _pageController;
  late int _currentIndex;
  final Map<int, TransformationController> _transformationControllers = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    
    // Initialize transformation controllers for each image
    for (int i = 0; i < widget.images.length; i++) {
      _transformationControllers[i] = TransformationController();
    }
    
    _checkStoragePermission();
  }

  @override
  void dispose() {
    _pageController.dispose();
    // Dispose all transformation controllers
    for (final controller in _transformationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _checkStoragePermission() async {
    // Check storage permission for Android 11+ (API 30+)
    if (await Permission.photos.request().isGranted) {
      // Permission is granted
    } else {
      // Show a snackbar to inform the user that they need to grant permission
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Storage permission is required to save photos to gallery'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      widget.images.removeAt(index);
    });
    
    // If we removed the last image, go back
    if (widget.images.isEmpty) {
      Navigator.pop(context);
      return;
    }
    
    // Adjust current index if needed
    if (_currentIndex >= widget.images.length) {
      _currentIndex = widget.images.length - 1;
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_currentIndex + 1} of ${widget.images.length}',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          // Remove button
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _removeImage(_currentIndex),
          ),
        ],
      ),
      body: Stack(
        children: [
          // PageView for swiping between images
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemCount: widget.images.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  // Optional: Hide/show app bar on tap
                },
                child: Center(
                  child: InteractiveViewer(
                    transformationController: _transformationControllers[index],
                    panEnabled: false, // Disable panning by default
                    boundaryMargin: const EdgeInsets.all(20),
                    minScale: 0.5,
                    maxScale: 4.0,
                    onInteractionEnd: (details) {
                      // Check if image is zoomed in
                      final controller = _transformationControllers[index];
                      if (controller != null) {
                        final scale = controller.value.getMaxScaleOnAxis();
                        // If not zoomed in, reset to center position
                        if (scale <= 1.0) {
                          controller.value = Matrix4.identity();
                        }
                      }
                    },
                    child: Image.file(
                      widget.images[index],
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              );
            },
          ),
          
          // Left Navigation Arrow
          if (_currentIndex > 0)
            Positioned(
              left: 20,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white,
                      size: 24,
                    ),
                    onPressed: () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                  ),
                ),
              ),
            ),
          
          // Right Navigation Arrow
          if (_currentIndex < widget.images.length - 1)
            Positioned(
              right: 20,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white,
                      size: 24,
                    ),
                    onPressed: () {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
} 
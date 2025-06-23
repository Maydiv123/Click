import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
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
  List<bool> _savedStatus = [];
  List<String> _errorMessages = [];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    
    // Initialize saved status and error messages
    _savedStatus = List.generate(widget.images.length, (_) => false);
    _errorMessages = List.generate(widget.images.length, (_) => '');
    
    _checkStoragePermission();
  }

  @override
  void dispose() {
    _pageController.dispose();
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

  Future<void> _saveImageToGallery(int index) async {
    try {
      final File imageFile = widget.images[index];
      final result = await ImageGallerySaver.saveFile(
        imageFile.path,
        name: "click_${DateTime.now().millisecondsSinceEpoch}"
      );
      
      if (result['isSuccess']) {
        setState(() {
          _savedStatus[index] = true;
          _errorMessages[index] = '';
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image saved to gallery successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        setState(() {
          _errorMessages[index] = result['errorMessage'] ?? 'Unknown error';
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save image: ${_errorMessages[index]}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _errorMessages[index] = e.toString();
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      widget.images.removeAt(index);
      _savedStatus.removeAt(index);
      _errorMessages.removeAt(index);
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
          // Save button
          IconButton(
            icon: Icon(
              _savedStatus[_currentIndex] ? Icons.check : Icons.save_alt, 
              color: Colors.white
            ),
            onPressed: () => _saveImageToGallery(_currentIndex),
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
                    panEnabled: true,
                    boundaryMargin: const EdgeInsets.all(20),
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.file(
                      widget.images[index],
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              );
            },
          ),
          
          // Error message overlay
          if (_errorMessages[_currentIndex].isNotEmpty)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Error: ${_errorMessages[_currentIndex]}',
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          
          // Save status indicator
          if (_savedStatus[_currentIndex])
            Positioned(
              top: 100,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Saved',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
} 
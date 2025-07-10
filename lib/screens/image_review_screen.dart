import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:video_player/video_player.dart';
import 'image_gallery_view_screen.dart';

class ImageReviewScreen extends StatefulWidget {
  final List<File> images;

  const ImageReviewScreen({
    Key? key,
    required this.images,
  }) : super(key: key);

  @override
  State<ImageReviewScreen> createState() => _ImageReviewScreenState();
}

class _ImageReviewScreenState extends State<ImageReviewScreen> {
  List<File> _images = [];
  
  // Share selection state
  bool _isSelectionMode = false;
  Set<int> _selectedImages = {};
  
  // Video player controllers
  Map<int, VideoPlayerController> _videoControllers = {};
  
  @override
  void initState() {
    super.initState();
    // Make images list mutable
    _images = List.from(widget.images);
    _checkStoragePermission();
    _initializeVideoControllers();
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
  
  Future<void> _deleteSelectedImages() async {
    if (_selectedImages.isEmpty) return;

    // Show confirmation dialog before deleting
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Images?'),
        content: Text(
          'Are you sure you want to delete the ${_selectedImages.length} selected images? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        // Sort indices in descending order to prevent issues when removing items from the list
        final indicesToRemove = _selectedImages.toList()..sort((a, b) => b.compareTo(a));
        
        for (final index in indicesToRemove) {
          _images.removeAt(index);
        }
        
        // Exit selection mode after deletion
        _clearSelection();
      });
    }
  }
  
  // Share selection methods
  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedImages.clear();
      }
    });
  }
  
  void _toggleImageSelection(int index) {
    setState(() {
      if (_selectedImages.contains(index)) {
        _selectedImages.remove(index);
      } else {
        _selectedImages.add(index);
      }
      
      // Exit selection mode if no images are selected
      if (_selectedImages.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }
  
  void _selectAllImages() {
    setState(() {
      _selectedImages = Set.from(List.generate(_images.length, (index) => index));
    });
  }
  
  void _clearSelection() {
    setState(() {
      _selectedImages.clear();
      _isSelectionMode = false;
    });
  }
  
  Future<void> _shareSelectedImages() async {
    if (_selectedImages.isEmpty) return;
    
    try {
      // Create list of selected image files
      final selectedFiles = _selectedImages.map((index) => _images[index]).toList();
      
      // Use share_plus package to share images
      await Share.shareXFiles(
        selectedFiles.map((file) => XFile(file.path)).toList(),
        text: 'Shared from Click App',
      );
      
      // Clear selection after sharing
      _clearSelection();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing images: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Navigate back to camera screen
  void _goBackToCamera() {
    // Return the updated list of images (with deleted ones removed)
    Navigator.pop(context, _images);
  }

  void _initializeVideoControllers() {
    for (int i = 0; i < _images.length; i++) {
      if (_isVideoFile(_images[i])) {
        _videoControllers[i] = VideoPlayerController.file(_images[i])
          ..initialize().then((_) {
            if (mounted) setState(() {});
          });
      }
    }
  }

  bool _isVideoFile(File file) {
    final extension = file.path.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(extension);
  }

  @override
  void dispose() {
    // Dispose all video controllers
    for (final controller in _videoControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: _isSelectionMode
          ? IconButton(
              icon: const Icon(Icons.close),
              onPressed: _clearSelection,
              tooltip: 'Cancel Selection',
            )
          : null, // Default back button
        title: Text(
          _isSelectionMode 
            ? '${_selectedImages.length} selected'
            : 'Review Photos (${_images.length})',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          // Select all button
          if (_isSelectionMode)
            IconButton(
              icon: Icon(
                _selectedImages.length == _images.length 
                  ? Icons.check_box 
                  : Icons.check_box_outline_blank,
              ),
              tooltip: 'Select All',
              onPressed: _selectedImages.length == _images.length
                ? _clearSelection
                : _selectAllImages,
            ),
          // Share button (only show when not in selection mode)
          if (!_isSelectionMode && _images.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Share photos',
              onPressed: _toggleSelectionMode,
            ),
          // Share button (show when in selection mode and images are selected)
          if (_isSelectionMode && _selectedImages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Share selected photos',
              onPressed: _shareSelectedImages,
            ),
          // Delete button (show when in selection mode and images are selected)
          if (_isSelectionMode && _selectedImages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete selected photos',
              onPressed: _deleteSelectedImages,
            ),
        ],
      ),
      body: Column(
        children: [
          // Image Count Badge
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: Colors.grey[50],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.photo_library, color: Colors.grey[600], size: 20),
                const SizedBox(width: 8),
                Text(
                  '${_images.length} photos captured',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Image Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _images.length + 1, // Add 1 for the plus button
              itemBuilder: (context, index) {
                // Show plus button at the beginning
                if (index == 0) {
                  return GestureDetector(
                    onTap: _isSelectionMode ? null : _goBackToCamera,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _isSelectionMode 
                          ? Colors.grey.withOpacity(0.1)
                          : const Color(0xFF35C2C1).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isSelectionMode 
                            ? Colors.grey.withOpacity(0.3)
                            : const Color(0xFF35C2C1).withOpacity(0.3),
                          width: 2,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _isSelectionMode 
                                ? Colors.grey.withOpacity(0.2)
                                : const Color(0xFF35C2C1).withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.add_a_photo,
                              color: _isSelectionMode 
                                ? Colors.grey
                                : const Color(0xFF35C2C1),
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Click More',
                            style: TextStyle(
                              color: _isSelectionMode 
                                ? Colors.grey
                                : const Color(0xFF35C2C1),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final imageIndex = index - 1;
                
                // Show image
                return GestureDetector(
                  onTap: () {
                    if (_isSelectionMode) {
                      // In selection mode, toggle selection
                      _toggleImageSelection(imageIndex);
                    } else {
                      // Normal mode, open gallery view
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ImageGalleryViewScreen(
                            images: _images,
                            initialIndex: imageIndex,
                          ),
                        ),
                      );
                    }
                  },
                  onLongPress: () {
                    if (!_isSelectionMode) {
                      // Start selection mode and select this image
                      _toggleSelectionMode();
                      _toggleImageSelection(imageIndex);
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      // Add selection border
                      border: _isSelectionMode && _selectedImages.contains(imageIndex)
                        ? Border.all(
                            color: const Color(0xFF35C2C1),
                            width: 3,
                          )
                        : null,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Display image or video
                          _isVideoFile(_images[imageIndex])
                            ? _buildVideoThumbnail(imageIndex)
                            : Image.file(
                                _images[imageIndex],
                                fit: BoxFit.cover,
                              ),
                          // Selection overlay
                          if (_isSelectionMode)
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: _selectedImages.contains(imageIndex)
                                  ? const Color(0xFF35C2C1).withOpacity(0.4)
                                  : Colors.black.withOpacity(0.2),
                              ),
                            ),
                          // Selection checkmark
                          if (_isSelectionMode && _selectedImages.contains(imageIndex))
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF35C2C1),
                                  shape: BoxShape.circle,
                                  border: Border.fromBorderSide(
                                    BorderSide(color: Colors.white, width: 1.5),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          
                          // Video play button overlay
                          if (_isVideoFile(_images[imageIndex]) && !_isSelectionMode)
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.play_arrow,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      'VIDEO',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          
                          // Image number badge - only show when not in selection mode
                          if (!_isSelectionMode)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${imageIndex + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      // Bottom action bar is now conditional
      bottomNavigationBar: _images.isEmpty
        ? SafeArea(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: _goBackToCamera,
                icon: const Icon(Icons.add_a_photo),
                label: const Text('Take More Photos'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF35C2C1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          )
        : null, // Hide bottom bar when viewing grid
    );
  }

  Widget _buildVideoThumbnail(int index) {
    final videoController = _videoControllers[index];
    if (videoController == null || !videoController.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }
    
    return Stack(
      fit: StackFit.expand,
      children: [
        VideoPlayer(videoController),
        // Video play overlay
        Container(
          color: Colors.black.withOpacity(0.3),
          child: const Center(
            child: Icon(
              Icons.play_circle_outline,
              color: Colors.white,
              size: 48,
            ),
          ),
        ),
      ],
    );
  }
}

class VideoPlayerScreen extends StatefulWidget {
  final VideoPlayerController videoController;

  const VideoPlayerScreen({
    Key? key,
    required this.videoController,
  }) : super(key: key);

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    widget.videoController.addListener(_videoListener);
  }

  void _videoListener() {
    if (mounted) {
      setState(() {
        _isPlaying = widget.videoController.value.isPlaying;
      });
    }
  }

  @override
  void dispose() {
    widget.videoController.removeListener(_videoListener);
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      if (_isPlaying) {
        widget.videoController.pause();
      } else {
        widget.videoController.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: AspectRatio(
          aspectRatio: widget.videoController.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(widget.videoController),
              // Play/Pause button overlay
              GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 
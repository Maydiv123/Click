import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';

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
  List<bool> _savedStatus = [];
  List<String> _errorMessages = [];
  
  @override
  void initState() {
    super.initState();
    // Initialize all images as not saved
    _savedStatus = List.generate(widget.images.length, (_) => false);
    _errorMessages = List.generate(widget.images.length, (_) => '');
    _checkStoragePermission();
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
  
  Future<void> _saveAllImagesToGallery() async {
    bool anySuccess = false;
    bool anyFailure = false;
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Saving images to gallery...'),
          ],
        ),
      ),
    );
    
    for (int i = 0; i < widget.images.length; i++) {
      if (!_savedStatus[i]) {
        try {
          final File imageFile = widget.images[i];
          final result = await ImageGallerySaver.saveFile(
            imageFile.path,
            name: "click_${DateTime.now().millisecondsSinceEpoch}_$i"
          );
          
          if (result['isSuccess']) {
            setState(() {
              _savedStatus[i] = true;
              _errorMessages[i] = '';
            });
            anySuccess = true;
          } else {
            setState(() {
              _errorMessages[i] = result['errorMessage'] ?? 'Unknown error';
            });
            anyFailure = true;
          }
        } catch (e) {
          setState(() {
            _errorMessages[i] = e.toString();
          });
          anyFailure = true;
        }
      }
    }
    
    // Close loading dialog
    if (mounted) {
      Navigator.of(context).pop();
    }
    
    // Show appropriate message
    if (mounted) {
      if (anySuccess && !anyFailure) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All images saved to gallery successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else if (anySuccess && anyFailure) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Some images were saved to gallery'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save images to gallery'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Review Photos (${widget.images.length})',
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
          // Add save all button
          IconButton(
            icon: const Icon(Icons.save_alt),
            tooltip: 'Save all to gallery',
            onPressed: _saveAllImagesToGallery,
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
                  '${widget.images.length} photos captured',
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
              itemCount: widget.images.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    // Show full-screen image preview
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Scaffold(
                          backgroundColor: Colors.black,
                          appBar: AppBar(
                            backgroundColor: Colors.black,
                            elevation: 0,
                            iconTheme: const IconThemeData(color: Colors.white),
                            actions: [
                              IconButton(
                                icon: Icon(
                                  _savedStatus[index] ? Icons.check : Icons.save_alt, 
                                  color: Colors.white
                                ),
                                onPressed: () => _saveImageToGallery(index),
                              ),
                            ],
                          ),
                          body: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Image.file(
                                    widget.images[index],
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                if (_errorMessages[index].isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    color: Colors.red.withOpacity(0.8),
                                    width: double.infinity,
                                    child: Text(
                                      'Error: ${_errorMessages[index]}',
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
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
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(
                            widget.images[index],
                            fit: BoxFit.cover,
                          ),
                          // Save status indicator
                          if (_savedStatus[index])
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          // Error indicator
                          if (_errorMessages[index].isNotEmpty)
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.error,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          // Save button
                          Positioned(
                            bottom: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: GestureDetector(
                                onTap: () => _saveImageToGallery(index),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _savedStatus[index] ? Icons.check : Icons.save_alt,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _savedStatus[index] ? 'Saved' : 'Save',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Image number badge
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
                                '${index + 1}',
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
      // Bottom action bar to save all images
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: _saveAllImagesToGallery,
          icon: const Icon(Icons.save_alt),
          label: const Text('Save All to Gallery'),
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
    );
  }
} 
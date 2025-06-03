import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';

class ImageReviewScreen extends StatelessWidget {
  final List<File> images;

  const ImageReviewScreen({
    Key? key,
    required this.images,
  }) : super(key: key);

  Future<void> _saveImages(BuildContext context) async {
    // Request storage permission
    final status = await Permission.storage.request();
    if (status.isDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Storage permission is required to save images')),
      );
      return;
    }

    try {
      for (File image in images) {
        await ImageGallerySaver.saveFile(image.path);
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Images saved to gallery')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error saving images')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Review Photos (${images.length})'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () => _saveImages(context),
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: images.length,
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
                      foregroundColor: Colors.white,
                      iconTheme: const IconThemeData(color: Colors.white),
                    ),
                    body: Center(
                      child: Image.file(
                        images[index],
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  images[index],
                  fit: BoxFit.cover,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
} 
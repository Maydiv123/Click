import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'image_review_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<File> _capturedImages = [];
  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    // Request camera permission
    final status = await Permission.camera.request();
    if (status.isDenied) {
      return;
    }

    // Get available cameras
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      return;
    }

    // Initialize camera controller
    _controller = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    try {
      final XFile photo = await _controller!.takePicture();
      setState(() {
        _capturedImages.add(File(photo.path));
      });
    } catch (e) {
      debugPrint('Error taking picture: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Take Photos'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          if (_capturedImages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ImageReviewScreen(
                      images: _capturedImages,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          // Camera Preview
          CameraPreview(_controller!),
          // Captured Images Preview
          if (_capturedImages.isNotEmpty)
            Positioned(
              bottom: 100,
              left: 16,
              child: Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.file(
                    _capturedImages.last,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _takePicture,
        backgroundColor: Colors.white,
        child: const Icon(Icons.camera, color: Colors.black),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
} 
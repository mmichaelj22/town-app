import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class CameraScreen extends StatelessWidget {
  final CameraController controller;

  const CameraScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(child: CameraPreview(controller)),
          ElevatedButton(
            onPressed: () async {
              final image = await controller.takePicture();
              Navigator.pop(context, File(image.path));
            },
            child: const Text('Take Selfie'),
          ),
        ],
      ),
    );
  }
}

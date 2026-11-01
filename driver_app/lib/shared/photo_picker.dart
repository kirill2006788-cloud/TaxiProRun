import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api/api_config.dart';
import '../models/registration_draft.dart';

/// Picks an image and returns raw base64 (same format as [MockPhotoData] / KYC draft).
Future<String?> pickImageBase64({
  ImageSource source = ImageSource.gallery,
  int imageQuality = 76,
  double maxWidth = 1280,
}) async {
  final file = await ImagePicker().pickImage(
    source: source,
    imageQuality: imageQuality,
    maxWidth: maxWidth,
  );
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  return base64Encode(bytes);
}

/// Bottom sheet: gallery or camera.
Future<ImageSource?> chooseImageSource(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Галерея'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Камера'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
        ],
      ),
    ),
  );
}

/// Real pick with mock fallback only when the whole app explicitly uses mock API.
Future<(String base64, bool usedMock)?> pickImageBase64OrMock(
  BuildContext context, {
  required String mockTag,
  bool? allowMockFallback,
}) async {
  final allowMock = allowMockFallback ?? ApiConfig.useMock;
  final source = await chooseImageSource(context);
  if (source == null) return null;
  try {
    final b64 = await pickImageBase64(source: source);
    if (b64 == null || b64.isEmpty) {
      if (allowMock) return (MockPhotoData.tagged(mockTag), true);
      return null;
    }
    return (b64, false);
  } catch (_) {
    if (allowMock) return (MockPhotoData.tagged(mockTag), true);
    return null;
  }
}

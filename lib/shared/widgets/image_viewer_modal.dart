import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/design_system/tokens/color_tokens.dart';
import '../../core/design_system/tokens/font_tokens.dart';

class ImageViewerModal extends StatelessWidget {
  final String imageUrl;
  final String title;

  const ImageViewerModal({
    super.key,
    required this.imageUrl,
    this.title = 'Vista previa de imagen',
  });

  static void show(BuildContext context, {required String imageUrl, String title = 'Vista previa'}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => ImageViewerModal(imageUrl: imageUrl, title: title),
    );
  }

  Widget _buildImage() {
    final cleanUrl = imageUrl.trim();
    if (cleanUrl.startsWith('data:image') || cleanUrl.length > 500) {
      try {
        final base64Str = cleanUrl.contains(',') ? cleanUrl.split(',').last : cleanUrl;
        final bytes = base64Decode(base64Str);
        return Image.memory(bytes, fit: BoxFit.contain);
      } catch (_) {}
    }

    if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')) {
      return Image.network(
        cleanUrl,
        fit: BoxFit.contain,
        errorBuilder: (ctx, err, stack) => const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image_outlined, size: 48, color: ColorTokens.lightTextSecondary),
            SizedBox(height: 8),
            Text('No se pudo cargar la imagen remota', style: TextStyle(color: ColorTokens.lightTextSecondary)),
          ],
        ),
      );
    }

    // Local file path
    final file = File(cleanUrl);
    if (file.existsSync()) {
      return Image.file(file, fit: BoxFit.contain);
    }

    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.image_not_supported_outlined, size: 48, color: ColorTokens.lightTextSecondary),
        SizedBox(height: 8),
        Text('Archivo de imagen no encontrado', style: TextStyle(color: ColorTokens.lightTextSecondary)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600, maxWidth: 500),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: FontTokens.h3.copyWith(
                        color: ColorTokens.lightTextPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: ColorTokens.lightTextSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Image Container
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                child: Container(
                  color: const Color(0xFF0F172A),
                  padding: const EdgeInsets.all(12),
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: Center(child: _buildImage()),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

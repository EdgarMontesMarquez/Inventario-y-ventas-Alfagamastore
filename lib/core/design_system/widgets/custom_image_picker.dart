import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../tokens/color_tokens.dart';
import '../tokens/font_tokens.dart';
import '../../../shared/widgets/image_viewer_modal.dart';

class CustomImagePicker extends StatefulWidget {
  final String? initialImageUrl;
  final String label;
  final ValueChanged<String?> onImageSelected;

  const CustomImagePicker({
    super.key,
    this.initialImageUrl,
    this.label = 'Imagen (Opcional)',
    required this.onImageSelected,
  });

  @override
  State<CustomImagePicker> createState() => _CustomImagePickerState();
}

class _CustomImagePickerState extends State<CustomImagePicker> {
  String? _currentImageUrl;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _currentImageUrl = widget.initialImageUrl;
  }

  @override
  void didUpdateWidget(covariant CustomImagePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialImageUrl != widget.initialImageUrl) {
      setState(() {
        _currentImageUrl = widget.initialImageUrl;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (photo != null) {
        final bytes = await photo.readAsBytes();
        final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';

        setState(() {
          _currentImageUrl = base64Str;
        });
        widget.onImageSelected(base64Str);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo acceder a la imagen seleccionada. Intente nuevamente.'),
            backgroundColor: ColorTokens.statusWarning,
          ),
        );
      }
    }
  }

  void _clearImage() {
    setState(() {
      _currentImageUrl = null;
    });
    widget.onImageSelected(null);
  }

  Widget _buildPreviewWidget() {
    if (_currentImageUrl == null || _currentImageUrl!.trim().isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.add_a_photo_outlined, color: ColorTokens.lightBrandPrimary, size: 28),
          const SizedBox(height: 6),
          Text(
            'Tocar para adjuntar foto o comprobante',
            style: FontTokens.bodySmall.copyWith(color: ColorTokens.lightTextSecondary, fontSize: 11),
          ),
        ],
      );
    }

    final clean = _currentImageUrl!.trim();

    Widget imgWidget;
    if (clean.startsWith('data:image') || clean.length > 500) {
      try {
        final base64Str = clean.contains(',') ? clean.split(',').last : clean;
        final bytes = base64Decode(base64Str);
        imgWidget = Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (ctx, err, stack) => Container(
            color: ColorTokens.lightBgSecondary,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image_outlined, color: ColorTokens.statusDanger, size: 24),
                SizedBox(height: 4),
                Text('Imagen no válida', style: TextStyle(fontSize: 10, color: ColorTokens.lightTextSecondary)),
              ],
            ),
          ),
        );
      } catch (_) {
        imgWidget = Container(
          color: ColorTokens.lightBgSecondary,
          child: const Icon(Icons.broken_image_outlined, color: ColorTokens.statusDanger),
        );
      }
    } else if (clean.startsWith('http://') || clean.startsWith('https://')) {
      imgWidget = Image.network(
        clean,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (ctx, err, stack) => Container(
          color: ColorTokens.lightBgSecondary,
          child: const Icon(Icons.broken_image_outlined, color: ColorTokens.statusDanger),
        ),
      );
    } else {
      final f = File(clean);
      if (f.existsSync()) {
        imgWidget = Image.file(f, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
      } else {
        imgWidget = Container(
          color: ColorTokens.lightBgSecondary,
          child: const Icon(Icons.image_not_supported_outlined, color: ColorTokens.lightTextSecondary),
        );
      }
    }

    return GestureDetector(
      onTap: () => ImageViewerModal.show(context, imageUrl: clean, title: widget.label),
      child: Stack(
        fit: StackFit.expand,
        children: [
          imgWidget,
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.visibility, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  void _showOptionsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.label, style: FontTokens.h3.copyWith(fontWeight: FontWeight.bold, color: ColorTokens.lightTextPrimary)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: ColorTokens.lightBrandPrimary),
                title: const Text('Tomar Foto con Cámara'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: ColorTokens.lightBrandPrimary),
                title: const Text('Elegir de Galería'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (_currentImageUrl != null) ...[
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: ColorTokens.statusDanger),
                  title: const Text('Eliminar Imagen', style: TextStyle(color: ColorTokens.statusDanger)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _clearImage();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(widget.label.toUpperCase(), style: FontTokens.label),
            if (_currentImageUrl != null)
              GestureDetector(
                onTap: _clearImage,
                child: Text('Quitar', style: FontTokens.label.copyWith(color: ColorTokens.statusDanger, fontSize: 10)),
              ),
          ],
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: _showOptionsModal,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              color: ColorTokens.lightBgSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ColorTokens.lightBorderSubtle),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _buildPreviewWidget(),
            ),
          ),
        ),
      ],
    );
  }
}

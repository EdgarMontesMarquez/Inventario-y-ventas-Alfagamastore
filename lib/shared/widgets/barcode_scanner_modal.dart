import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/design_system/tokens/color_tokens.dart';
import '../../core/design_system/tokens/font_tokens.dart';
import '../../core/design_system/tokens/border_shadow_tokens.dart';
import '../../core/design_system/widgets/custom_buttons.dart';
import '../../core/design_system/widgets/custom_inputs.dart';

class BarcodeScannerModal extends StatefulWidget {
  const BarcodeScannerModal({super.key});

  static Future<String?> scan(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const BarcodeScannerModal(),
    );
  }

  @override
  State<BarcodeScannerModal> createState() => _BarcodeScannerModalState();
}

class _BarcodeScannerModalState extends State<BarcodeScannerModal> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  final _manualCodeCtrl = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isScanned = false;
  bool _isTorchOn = false;
  bool _hasPermission = false;
  bool _isPermissionChecked = false;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (mounted) {
      setState(() {
        _hasPermission = status.isGranted;
        _isPermissionChecked = true;
      });
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _controller.dispose();
    _manualCodeCtrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isScanned) return;
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.trim().isNotEmpty) {
        _isScanned = true;
        try {
          _audioPlayer.play(AssetSource('sounds/beep_scaner.mp3'), mode: PlayerMode.lowLatency);
        } catch (_) {}
        SystemSound.play(SystemSoundType.click);
        HapticFeedback.mediumImpact();
        HapticFeedback.vibrate();
        await Future.delayed(const Duration(milliseconds: 150));
        if (mounted) {
          Navigator.pop(context, rawValue.trim());
        }
        break;
      }
    }
  }

  void _confirmCode(String code) {
    if (code.trim().isNotEmpty) {
      Navigator.pop(context, code.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: ColorTokens.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle & Header
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: ColorTokens.textDim,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.camera_alt_outlined, color: ColorTokens.primary, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      'ESCANEAR CÓDIGO DE BARRAS',
                      style: FontTokens.label.copyWith(
                        color: ColorTokens.text,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    _isTorchOn ? Icons.flash_on : Icons.flash_off,
                    color: _isTorchOn ? ColorTokens.warning : ColorTokens.textMuted,
                  ),
                  onPressed: () {
                    setState(() {
                      _isTorchOn = !_isTorchOn;
                    });
                    _controller.toggleTorch();
                  },
                ),
              ],
            ),
          ),
          const Divider(),

          // Live Hardware Camera Viewfinder Feed
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ColorTokens.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ColorTokens.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: !_isPermissionChecked
                    ? const Center(child: CircularProgressIndicator(color: ColorTokens.primary))
                    : _hasPermission
                        ? Stack(
                            alignment: Alignment.center,
                            children: [
                              MobileScanner(
                                controller: _controller,
                                onDetect: _onDetect,
                              ),
                              Container(
                                width: 260,
                                height: 160,
                                decoration: BoxDecoration(
                                  border: Border.all(color: ColorTokens.primary, width: 2.5),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: BorderShadowTokens.shadowPrimary,
                                ),
                              ),
                              Positioned(
                                bottom: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withAlpha(180),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Enfoca el código de barras con la cámara',
                                    style: FontTokens.bodySmall.copyWith(color: Colors.white, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.videocam_off_outlined, size: 48, color: ColorTokens.error),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Permiso de Cámara Requerido',
                                    style: FontTokens.h3,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Concede permiso de cámara o ingresa el código SKU manualmente.',
                                    style: FontTokens.bodySmall.copyWith(color: ColorTokens.textMuted),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  CustomButton(
                                    text: 'Solicitar Permiso',
                                    isFullWidth: false,
                                    onPressed: _requestCameraPermission,
                                  ),
                                ],
                              ),
                            ),
                          ),
              ),
            ),
          ),

          // Manual SKU Input Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    label: '',
                    hint: 'Ingresar SKU manualmente…',
                    controller: _manualCodeCtrl,
                  ),
                ),
                const SizedBox(width: 10),
                CustomButton(
                  text: 'Usar SKU',
                  isFullWidth: false,
                  onPressed: () => _confirmCode(_manualCodeCtrl.text),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

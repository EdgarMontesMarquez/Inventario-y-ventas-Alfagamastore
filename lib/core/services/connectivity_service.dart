import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _onlineStreamController = StreamController<bool>.broadcast();
  bool _isOnline = true;
  Timer? _heartbeatTimer;

  bool get isOnline => _isOnline;
  Stream<bool> get onlineStream => _onlineStreamController.stream;

  void initialize() {
    // Escuchar cambios de red del sistema
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _checkActualInternet(results);
    });

    // Verificación inicial inmediata
    checkConnection();

    // Heartbeat periódico cada 15 segundos para detectar caídas silenciosas
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      checkConnection();
    });
  }

  Future<bool> checkConnection() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return await _checkActualInternet(results);
    } catch (_) {
      return await _testLookup();
    }
  }

  Future<bool> _checkActualInternet(List<ConnectivityResult> results) async {
    final bool hasInterface = results.any((r) => r != ConnectivityResult.none);
    if (!hasInterface) {
      _setOnline(false);
      return false;
    }

    final bool reachable = await _testLookup();
    _setOnline(reachable);
    return reachable;
  }

  Future<bool> _testLookup() async {
    try {
      if (kIsWeb) return true; // En web el navegador maneja la conexión
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 4));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      try {
        final result = await InternetAddress.lookup('1.1.1.1')
            .timeout(const Duration(seconds: 4));
        return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } catch (_) {
        return false;
      }
    }
  }

  void _setOnline(bool online) {
    if (_isOnline != online) {
      _isOnline = online;
      _onlineStreamController.add(_isOnline);
      debugPrint('🌐 Conectividad cambiada: ${online ? "EN LÍNEA" : "SIN CONEXIÓN (OFFLINE)"}');
    }
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    _onlineStreamController.close();
  }
}

// Riverpod Provider para el estado de conectividad en tiempo real
final isOnlineProvider = StreamProvider<bool>((ref) {
  final service = ConnectivityService();
  return service.onlineStream;
});

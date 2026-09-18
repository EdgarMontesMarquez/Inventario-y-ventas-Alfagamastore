import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class SyncAction {
  final String id;
  final String type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int retryCount;

  SyncAction({
    required this.id,
    required this.type,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'payload': payload,
    'created_at': createdAt.toIso8601String(),
    'retry_count': retryCount,
  };

  factory SyncAction.fromJson(Map<String, dynamic> json) => SyncAction(
    id: json['id']?.toString() ?? '',
    type: json['type']?.toString() ?? '',
    payload: Map<String, dynamic>.from(json['payload'] ?? {}),
    createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) ?? DateTime.now() : DateTime.now(),
    retryCount: (json['retry_count'] as num? ?? 0).toInt(),
  );

  SyncAction incrementRetry() => SyncAction(
    id: id,
    type: type,
    payload: payload,
    createdAt: createdAt,
    retryCount: retryCount + 1,
  );
}

class SyncQueueService {
  static final SyncQueueService _instance = SyncQueueService._internal();
  factory SyncQueueService() => _instance;
  SyncQueueService._internal();

  Directory? _storageDir;

  Future<Directory> _getDir() async {
    if (_storageDir != null) return _storageDir!;
    try {
      _storageDir = await getApplicationDocumentsDirectory();
    } catch (_) {
      _storageDir = Directory.current;
    }
    return _storageDir!;
  }

  Future<File> _getFile() async {
    final dir = await _getDir();
    final file = File('${dir.path}/alfagama_sync_queue.json');
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    return file;
  }

  Future<List<SyncAction>> getQueue() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];
      final List<dynamic> list = jsonDecode(content);
      return list.map((item) => SyncAction.fromJson(item)).toList();
    } catch (e) {
      debugPrint('Error leyendo sync_queue: $e');
      return [];
    }
  }

  Future<void> enqueue(SyncAction action) async {
    final list = await getQueue();
    // Evitar duplicados con mismo ID
    list.removeWhere((a) => a.id == action.id);
    list.add(action);
    await _saveQueue(list);
  }

  Future<void> removeAction(String actionId) async {
    final list = await getQueue();
    list.removeWhere((a) => a.id == actionId);
    await _saveQueue(list);
  }

  Future<void> updateAction(SyncAction action) async {
    final list = await getQueue();
    final index = list.indexWhere((a) => a.id == action.id);
    if (index >= 0) {
      list[index] = action;
      await _saveQueue(list);
    }
  }

  Future<int> getPendingCount() async {
    final list = await getQueue();
    return list.length;
  }

  Future<void> _saveQueue(List<SyncAction> list) async {
    try {
      final file = await _getFile();
      final data = list.map((a) => a.toJson()).toList();
      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (e) {
      debugPrint('Error guardando sync_queue: $e');
    }
  }

  Future<void> clearQueue() async {
    await _saveQueue([]);
  }
}

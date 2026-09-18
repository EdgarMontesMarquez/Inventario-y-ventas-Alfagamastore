import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/services/offline_storage_service.dart';
import '../../../core/services/sync_queue_service.dart';

class CategoryNotifier extends Notifier<List<String>> {
  final OfflineStorageService _storage = OfflineStorageService();
  final SyncQueueService _queue = SyncQueueService();

  @override
  List<String> build() {
    _loadCategories();
    return ['Todos'];
  }

  Future<void> _loadCategories() async {
    // 1. Cargar local primero
    final localCats = await _storage.getCategories();
    if (localCats.isNotEmpty) {
      state = localCats;
    }

    // 2. Intentar actualizar desde Supabase
    try {
      final res = await Supabase.instance.client
          .from('categories')
          .select('name')
          .order('name');
      final list = (res as List).map((e) => e['name'].toString()).toList();
      if (list.isNotEmpty) {
        final combined = ['Todos', ...list];
        state = combined;
        await _storage.saveCategories(combined);
      }
    } catch (_) {}
  }

  Future<void> addCategory(String category) async {
    final trimmed = category.trim();
    if (trimmed.isEmpty) return;

    if (!state.contains(trimmed)) {
      final newState = [...state, trimmed];
      state = newState;
      await _storage.saveCategories(newState);
    }

    try {
      await Supabase.instance.client.from('categories').insert({'name': trimmed});
    } catch (_) {
      await _queue.enqueue(SyncAction(
        id: const Uuid().v4(),
        type: 'ADD_CATEGORY',
        payload: {'name': trimmed},
        createdAt: DateTime.now(),
      ));
    }
  }
}

final categoryProvider = NotifierProvider<CategoryNotifier, List<String>>(() {
  return CategoryNotifier();
});

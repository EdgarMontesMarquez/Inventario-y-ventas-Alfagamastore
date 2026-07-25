import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CategoryNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    _fetchCategoriesFromSupabase();
    return ['Todos'];
  }

  Future<void> _fetchCategoriesFromSupabase() async {
    try {
      final res = await Supabase.instance.client
          .from('categories')
          .select('name')
          .order('name');
      final list = (res as List).map((e) => e['name'].toString()).toList();
      if (list.isNotEmpty) {
        state = ['Todos', ...list];
      }
    } catch (_) {}
  }

  Future<void> addCategory(String category) async {
    final trimmed = category.trim();
    if (trimmed.isEmpty) return;

    if (!state.contains(trimmed)) {
      state = [...state, trimmed];
    }

    try {
      await Supabase.instance.client.from('categories').insert({'name': trimmed});
    } catch (_) {}
  }
}

final categoryProvider = NotifierProvider<CategoryNotifier, List<String>>(() {
  return CategoryNotifier();
});

// lib/services/beneficiaries_store.dart
import 'package:get_storage/get_storage.dart';

class BeneficiariesStore {
  static final _box = GetStorage('beneficiaries');
  static List<Map<String, dynamic>> all() =>
      List<Map<String, dynamic>>.from(_box.read('list') ?? []);
  static void upsert(Map<String, dynamic> bene) {
    final list = all();
    list.removeWhere((e) => e['id'] == bene['id']);
    list.insert(0, bene);
    _box.write('list', list.take(20).toList());
  }
}

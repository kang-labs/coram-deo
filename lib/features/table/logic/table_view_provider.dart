import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/local_storage.dart';

/// 체크표 탭 보기 방식. [name]이 저장 키라 바꾸지 마세요.
enum TableView {
  /// 한 주씩 크게 (반장에게 보여 줄 때)
  week('주별'),

  /// 종이와 같은 표
  grid('표');

  const TableView(this.label);

  final String label;

  static TableView fromName(String? name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return week;
  }
}

/// 고른 보기 방식 (기기에 기억)
final tableViewProvider = NotifierProvider<TableViewController, TableView>(TableViewController.new);

class TableViewController extends Notifier<TableView> {
  static const storageKey = 'tableView';

  @override
  TableView build() => TableView.fromName(ref.watch(sharedPreferencesProvider).getString(storageKey));

  Future<void> select(TableView v) async {
    if (v == state) return;
    state = v;
    await ref.read(sharedPreferencesProvider).setString(storageKey, v.name);
  }
}

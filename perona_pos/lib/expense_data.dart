import 'domain.dart';

const expenseCategories = [
  'Bahan & peralatan',
  'Listrik & air',
  'Sewa',
  'Transportasi',
  'Perawatan',
  'Lainnya',
];

class ExpenseReport {
  final int total, count, historyCount, drawerCash;
  final List<Json> rows, categories;
  ExpenseReport.fromJson(Json json)
    : total = money(json['total']),
      count = money(json['count']),
      historyCount = money(json['history_count']),
      drawerCash = money(json['drawer_cash']),
      rows =
          ((json['rows'] as List?) ?? [])
              .map((r) => Json.from(r as Map))
              .toList(),
      categories =
          ((json['categories'] as List?) ?? [])
              .map((r) => Json.from(r as Map))
              .toList();
}

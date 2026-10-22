import 'domain.dart';

String cashDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class CashDay {
  final DateTime date;
  final int cash, qris, transfer, total, count;
  final String fingerprint;
  final List<Json> payments;
  final Json? closing;
  CashDay.fromJson(Json row)
    : date = DateTime.parse(row['date'] as String),
      cash = money(row['cash']),
      qris = money(row['qris']),
      transfer = money(row['transfer']),
      total = money(row['total']),
      count = money(row['count']),
      fingerprint = row['fingerprint'] as String,
      payments =
          ((row['payments'] as List?) ?? [])
              .map((p) => Json.from(p as Map))
              .toList(),
      closing =
          row['closing'] == null ? null : Json.from(row['closing'] as Map);
  bool get changedSinceClosing =>
      closing != null && closing!['source_fingerprint'] != fingerprint;
}

class CashCount {
  final int opening, received, cashOut, counted;
  const CashCount({
    required this.opening,
    required this.received,
    required this.cashOut,
    required this.counted,
  });
  int get expected => opening + received - cashOut;
  int get difference => counted - expected;
}

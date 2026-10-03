import '../lib/domain.dart';
void main() {
  var checks = 0;
  void check(bool condition, String label) {
    if (!condition) throw StateError(label);
    checks++;
  }
  Json line(int price, int fee, int qty) => {'price': price, 'labor_fee': fee, 'quantity': qty};
  final t = Totals.fromItems([line(30000, 10000, 2), line(50000, 20000, 1)], 10000);
  check(t.gross == 110000 && t.revenue == 100000 && t.labor == 40000 && t.contribution == 60000, 'Upah tetap saat diskon');
  check(Totals.fromItems([line(20000, 7500, 3)], 0).labor == 22500, 'Ongkos 7500');
  for (final input in [line(30000, 10000, 0), line(30000, 10000, 1000), {'price': 30000, 'quantity': 1}]) {
    var rejected = false;
    try { Totals.fromItems([input], 0); } on ArgumentError { rejected = true; }
    check(rejected, 'Input invalid harus ditolak');
  }
  for (final discount in [-1, 30001]) {
    var rejected = false;
    try { Totals.fromItems([line(30000, 10000, 1)], discount); } on ArgumentError { rejected = true; }
    check(rejected, 'Diskon invalid ditolak');
  }
  final day = Period.forDate(DateTime(2026, 10, 2), 'day');
  check(day.start == DateTime.utc(2026, 10, 1, 17) && day.end == DateTime.utc(2026, 10, 2, 17), 'Batas harian WIB');
  check(day.contains(day.start) && !day.contains(day.end), 'Periode start inclusive end exclusive');
  final month = Period.forDate(DateTime(2026, 12, 15), 'month');
  check(month.end == DateTime.utc(2026, 12, 31, 17), 'Desember ke Januari');
  check(Period.forDate(DateTime(2028, 2, 1), 'month').end.difference(Period.forDate(DateTime(2028, 2, 1), 'month').start).inDays == 29, 'Februari kabisat');
  final year = Period.forDate(DateTime(2028, 6, 1), 'year');
  check(year.end.difference(year.start).inDays == 366, 'Tahun kabisat');
  print('PASS: $checks pemeriksaan domain Dart tanpa Flutter');
}

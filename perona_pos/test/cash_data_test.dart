import 'package:flutter_test/flutter_test.dart';
import 'package:perona_pos/cash_data.dart';

void main() {
  test(
    'cash date keeps calendar components regardless of time or UTC flag',
    () {
      expect(cashDate(DateTime.utc(2026, 10, 23, 23, 59)), '2026-10-23');
      expect(cashDate(DateTime(2026, 1, 2, 1)), '2026-01-02');
    },
  );

  test('drawer balance uses opening and cash receipts minus cash out', () {
    const short = CashCount(
      opening: 100000,
      received: 30000,
      cashOut: 10000,
      counted: 119000,
    );
    expect(short.expected, 120000);
    expect(short.difference, -1000);
    expect(
      const CashCount(
        opening: 100000,
        received: 30000,
        cashOut: 10000,
        counted: 121000,
      ).difference,
      1000,
    );
    expect(
      const CashCount(
        opening: 0,
        received: 0,
        cashOut: 0,
        counted: 0,
      ).difference,
      0,
    );
  });

  test('report tracks receipt changes separately from a stored closing', () {
    final row = <String, dynamic>{
      'date': '2026-10-23',
      'cash': 30000,
      'qris': 50000,
      'transfer': 20000,
      'total': 100000,
      'count': 3,
      'fingerprint': 'new',
      'payments': [],
      'closing': {'source_fingerprint': 'old', 'cash_received': 25000},
    };
    final report = CashDay.fromJson(row);
    expect(report.total, 100000);
    expect(report.changedSinceClosing, isTrue);
    expect(report.closing!['cash_received'], 25000);
    expect(
      CashDay.fromJson({
        ...row,
        'closing': {'source_fingerprint': 'new'},
      }).changedSinceClosing,
      isFalse,
    );
    expect(
      CashDay.fromJson({...row, 'closing': null}).changedSinceClosing,
      isFalse,
    );
  });
}

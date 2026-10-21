import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perona_pos/domain.dart';
import 'package:perona_pos/report_data.dart';

import 'home_page_test.dart'
    show DemoRepository, pumpHome, capture, loadPreviewFonts;
import 'report_data_test.dart' show sampleOrder;
import 'wage_detail_test.dart' show tapVisible;

class SummaryRepository extends DemoRepository {
  final month = Period.forDate(jakarta(DateTime.now()), 'month');
  final reads = <(Period, int, String?)>[];
  final rows = <Json>[];

  SummaryRepository() {
    Json row(int n, int total, List<Json> payments) => {
      ...sampleOrder(
        index: n,
        createdAt:
            (n == 4
                    ? month.end.subtract(const Duration(seconds: 1))
                    : month.start)
                .toIso8601String(),
      ),
      'customer_name': n <= 2 ? 'Andi' : 'Customer $n',
      'phone':
          n == 1
              ? '0812 123456'
              : n == 2
              ? '+62 812123456'
              : '0812000$n',
      'notes': '',
      'total': total,
      'payments': payments,
    };
    rows.addAll([
      row(1, 100000, [
        {'id': 'p1', 'method': 'QRIS', 'amount': 25000, 'voided_at': null},
        {'id': 'p2', 'method': 'Tunai', 'amount': 25000, 'voided_at': null},
      ]),
      row(2, 40000, []),
      row(3, 80000, [
        {'id': 'p3', 'method': 'QRIS', 'amount': 80000, 'voided_at': null},
        {
          'id': 'p4',
          'method': 'Tunai',
          'amount': 999000,
          'voided_at': '2026-10-01T00:00:00Z',
        },
      ]),
      row(4, 60000, [
        {'id': 'p5', 'method': 'Tunai', 'amount': 60000, 'voided_at': null},
      ]),
      {
        ...row(90, 1000000, []),
        'created_at':
            month.start.subtract(const Duration(seconds: 1)).toIso8601String(),
      },
      {...row(91, 1000000, []), 'created_at': month.end.toIso8601String()},
      {...row(92, 1000000, []), 'deleted_at': month.start.toIso8601String()},
    ]);
  }

  @override
  Future<List<Json>> orders(Period period, int page, {String? workerId}) async {
    reads.add((period, page, workerId));
    if (this.fail) throw StateError('Koneksi pengujian terputus.');
    return rows.skip(page * 30).take(30).toList();
  }

  @override
  Future<Json> order(String id) async =>
      rows.firstWhere((row) => row['id'] == id);
}

Future<void> openCategory(WidgetTester tester, String id) =>
    tapVisible(tester, find.byKey(ValueKey('payment-summary-$id')));

void main() {
  setUpAll(loadPreviewFonts);

  test(
    'monthly categories include WIB boundaries and exclude removed orders',
    () {
      final repo = SummaryRepository();
      final overview = PaymentOverview(repo.rows, repo.month);
      expect(overview.orders.map((o) => o['id']), [
        'order-1',
        'order-2',
        'order-3',
        'order-4',
      ]);
      expect(overview.customerCountFor(PaymentCategory.unpaid), 1);
      expect(overview.ordersFor(PaymentCategory.unpaid).length, 2);
      expect(overview.amountFor(PaymentCategory.unpaid), 90000);
    },
  );

  test(
    'mixed payments appear in both categories without doubling method amounts',
    () {
      final repo = SummaryRepository();
      final overview = PaymentOverview(repo.rows, repo.month);
      expect(overview.ordersFor(PaymentCategory.qris).map((o) => o['id']), [
        'order-1',
        'order-3',
      ]);
      expect(overview.ordersFor(PaymentCategory.cash).map((o) => o['id']), [
        'order-1',
        'order-4',
      ]);
      expect(overview.amountFor(PaymentCategory.qris), 105000);
      expect(overview.amountFor(PaymentCategory.cash), 85000);
    },
  );

  testWidgets(
    'summary shows four monthly metrics with live counts and payment amounts',
    (tester) async {
      final repo = SummaryRepository();
      await pumpHome(tester, repo, 'owner');
      for (final label in [
        'Total order bulan ini',
        'Customer belum lunas',
        'Bayar QRIS',
        'Bayar tunai',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Pembayaran masuk'), findsNothing);
      expect(find.text('Piutang usaha'), findsNothing);
      expect(find.text('Diskon'), findsNothing);
      expect(find.text('PERIODE REKAP'), findsNothing);
      expect(find.text('Rp105.000'), findsOneWidget);
      expect(find.text('Rp85.000'), findsOneWidget);
      expect(find.text('Sisa tagihan Rp90.000'), findsOneWidget);
      expect(repo.reads.last.$1.start, repo.month.start);
      expect(repo.reads.last.$1.end, repo.month.end);
      expect(repo.reads.last.$3, isNull);
      expect(repo.reportReads, 0);
      await capture(tester, 'monthly-summary-simple');
    },
  );

  for (final category in PaymentCategory.values) {
    testWidgets('${category.name} opens a four-column customer table', (
      tester,
    ) async {
      final repo = SummaryRepository();
      await pumpHome(tester, repo, 'owner');
      await openCategory(tester, category.name);
      expect(find.text(category.label), findsOneWidget);
      final table = tester.widget<DataTable>(find.byType(DataTable));
      expect(table.columns.map((c) => (c.label as Text).data), [
        'No',
        'Tanggal',
        'Nama customer',
        'Keterangan bayar',
      ]);
      expect(table.rows.length, 2);
      final descriptions = table.rows
          .map((row) => ((row.cells[3].child as SizedBox).child as Text).data!)
          .join('\n');
      if (category == PaymentCategory.unpaid) {
        expect(find.textContaining('1 customer · 2 nota'), findsOneWidget);
        expect(descriptions, contains('Belum bayar'));
        expect(descriptions, contains('DP'));
        expect(descriptions, contains('Sisa Rp50.000'));
        expect(descriptions, contains('Sisa Rp40.000'));
      } else {
        expect(descriptions, contains('${category.method} Rp25.000'));
        expect(descriptions, contains('Total dibayar Rp50.000'));
        expect(descriptions, contains('Lunas'));
      }
      if (category == PaymentCategory.qris) {
        await capture(tester, 'monthly-summary-qris-detail');
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'opening original receipt refreshes category and dashboard after a payment',
    (tester) async {
      final repo = SummaryRepository();
      await pumpHome(tester, repo, 'owner');
      await openCategory(tester, 'unpaid');
      await tapVisible(tester, find.text('Andi\nNota #2'));
      expect(find.text('Detail order'), findsOneWidget);
      repo.rows[1]['payments'] = [
        {
          'id': 'settled',
          'method': 'Tunai',
          'amount': 40000,
          'voided_at': null,
        },
      ];
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(tester.widget<DataTable>(find.byType(DataTable)).rows.length, 1);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Rp125.000'), findsOneWidget);
      expect(find.text('Sisa tagihan Rp50.000'), findsOneWidget);
    },
  );

  testWidgets(
    'category loading failures retry and empty categories show an explanation',
    (tester) async {
      final repo = SummaryRepository();
      await pumpHome(tester, repo, 'owner');
      repo.fail = true;
      await openCategory(tester, 'cash');
      expect(find.text('Rincian belum bisa dimuat'), findsOneWidget);
      repo.fail = false;
      repo.rows.clear();
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      expect(find.text('Belum ada customer pada kategori ini'), findsOneWidget);
    },
  );

  testWidgets('summary and detail read all pages beyond thirty orders', (
    tester,
  ) async {
    final repo = SummaryRepository();
    repo.rows.clear();
    for (var i = 0; i < 61; i++) {
      repo.rows.add({
        ...sampleOrder(index: i, createdAt: repo.month.start.toIso8601String()),
        'notes': '',
      });
    }
    await pumpHome(tester, repo, 'owner');
    expect(repo.reads.map((r) => r.$2), [0, 1, 2]);
    expect(find.text('Rp1.830.000'), findsOneWidget);
    repo.reads.clear();
    await openCategory(tester, 'qris');
    expect(repo.reads.map((r) => r.$2), [0, 1, 2]);
    expect(tester.widget<DataTable>(find.byType(DataTable)).rows.length, 61);
  });

  testWidgets('changing wage period does not change current-month summary', (
    tester,
  ) async {
    final repo = SummaryRepository();
    await pumpHome(tester, repo, 'staff');
    await tester.tap(find.text('Ongkos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tahunan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ringkasan'));
    await tester.pumpAndSettle();
    expect(repo.reads.last.$1.start, repo.month.start);
    expect(repo.reads.last.$1.end, repo.month.end);
    expect(find.text('Rp105.000'), findsOneWidget);
  });

  testWidgets(
    'small phone with enlarged text can open and scroll payment details',
    (tester) async {
      final repo = SummaryRepository();
      await pumpHome(
        tester,
        repo,
        'owner',
        size: const Size(320, 740),
        textScale: 1.5,
      );
      await openCategory(tester, 'cash');
      final horizontal = find.byWidgetPredicate(
        (w) =>
            w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
      );
      await tester.drag(horizontal, const Offset(-700, 0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}

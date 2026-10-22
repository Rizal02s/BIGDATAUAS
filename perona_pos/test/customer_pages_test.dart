import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perona_pos/domain.dart';

import 'home_page_test.dart' show pumpHome, capture, loadPreviewFonts;
import 'payment_summary_test.dart' show SummaryRepository;
import 'report_data_test.dart' show sampleOrder;
import 'wage_detail_test.dart' show tapVisible;

DateTime get previousMonth {
  final now = jakarta(DateTime.now());
  return DateTime.utc(now.year, now.month - 1);
}

class CustomerRepository extends SummaryRepository {
  CustomerRepository() {
    rows.clear();
    var n = 0;
    for (var customer = 1; customer <= 7; customer++) {
      for (var visit = 0; visit < 8 - customer; visit++) {
        n++;
        rows.add({
          ...sampleOrder(
            index: n,
            createdAt: month.start.add(Duration(days: visit)).toIso8601String(),
          ),
          'customer_name': 'Pelanggan $customer',
          'phone': '0812000$customer',
          'notes': '',
          'payments': [],
        });
      }
    }
    rows.add({
      ...sampleOrder(
        index: 99,
        createdAt:
            DateTime.utc(
              previousMonth.year,
              previousMonth.month,
              12,
              16,
              59,
              59,
            ).toIso8601String(),
      ),
      'customer_name': 'Pelanggan periode lalu',
      'phone': '',
      'notes': '',
    });
  }
}

Future<void> showCard(WidgetTester tester) async {
  tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position
      .jumpTo(0);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('customer-date-range')),
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await Scrollable.ensureVisible(
    tester.element(find.text('Top 5 pelanggan')),
    alignment: 0.02,
  );
  await tester.pumpAndSettle();
}

Future<void> choosePastRange(WidgetTester tester) async {
  await tapVisible(tester, find.byKey(const ValueKey('customer-date-range')));
  expect(find.text('Pilih periode pelanggan'), findsOneWidget);
  await tester.tap(find.byTooltip('Switch to input'));
  await tester.pumpAndSettle();
  final fields = find.byType(TextField);
  final month = previousMonth.month.toString().padLeft(2, '0');
  await tester.enterText(fields.at(0), '$month/10/${previousMonth.year}');
  await tester.enterText(fields.at(1), '$month/12/${previousMonth.year}');
  await tester.tap(find.text('Terapkan').last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadPreviewFonts);
  final pastLabel =
      '10/${previousMonth.month.toString().padLeft(2, '0')}/${previousMonth.year} – '
      '12/${previousMonth.month.toString().padLeft(2, '0')}/${previousMonth.year}';

  testWidgets(
    'summary shows only top five and all customers opens without another tab',
    (tester) async {
      final repo = CustomerRepository();
      await pumpHome(tester, repo, 'owner');
      expect(repo.reads, hasLength(1));
      await showCard(tester);
      expect(find.text('Top 5 pelanggan'), findsOneWidget);
      expect(find.byKey(const ValueKey('customer-rank-5')), findsOneWidget);
      expect(find.byKey(const ValueKey('customer-rank-6')), findsNothing);
      expect(find.text('7 kunjungan'), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).destinations,
        hasLength(5),
      );
      await capture(tester, 'top-customers-summary');
      await tapVisible(tester, find.byKey(const ValueKey('all-customers')));
      expect(find.text('Peringkat pelanggan'), findsOneWidget);
      expect(find.byKey(const ValueKey('customer-rank-7')), findsOneWidget);
      expect(find.text('Pelanggan periode lalu'), findsNothing);
      await capture(tester, 'customer-ranking');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'customer opens receipts with services dates and amounts, then original order',
    (tester) async {
      final repo = CustomerRepository();
      await pumpHome(tester, repo, 'owner');
      await tapVisible(tester, find.byKey(const ValueKey('customer-rank-1')));
      expect(find.text('Riwayat pelanggan'), findsOneWidget);
      expect(find.text('7 kunjungan'), findsOneWidget);
      expect(find.text('Total transaksi Rp595.000'), findsOneWidget);
      expect(find.text('Deep Clean × 2'), findsWidgets);
      expect(find.text('Perawatan sepatu kulit × 1'), findsWidgets);
      expect(find.textContaining('WIB'), findsWidgets);
      expect(
        find.byKey(const ValueKey('customer-receipt-order-7')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('customer-receipt-order-8')),
        findsNothing,
      );
      await capture(tester, 'customer-history');
      await tapVisible(
        tester,
        find.byKey(const ValueKey('customer-receipt-order-7')),
      );
      expect(find.text('Detail order'), findsOneWidget);
      repo.rows.removeWhere((row) => row['id'] == 'order-7');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('6 kunjungan'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await showCard(tester);
      expect(find.text('7 kunjungan'), findsNothing);
      expect(find.text('6 kunjungan'), findsWidgets);
    },
  );

  testWidgets(
    'calendar applies inclusive custom dates and preserves separate monthly finance',
    (tester) async {
      final repo = CustomerRepository();
      await pumpHome(tester, repo, 'owner');
      await choosePastRange(tester);
      expect(find.text(pastLabel), findsOneWidget);
      expect(find.text('Pelanggan periode lalu'), findsOneWidget);
      expect(find.text('1 kunjungan'), findsOneWidget);
      expect(
        repo.reads.last.$1.start,
        DateTime.utc(previousMonth.year, previousMonth.month, 9, 17),
      );
      expect(
        repo.reads.last.$1.end,
        DateTime.utc(previousMonth.year, previousMonth.month, 12, 17),
      );
      expect(repo.reads.last.$3, isNull);
      await tester.tap(find.text('Ongkos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ringkasan'));
      await tester.pumpAndSettle();
      expect(find.text('Total order bulan ini'), findsOneWidget);
      await showCard(tester);
      expect(find.text(pastLabel), findsOneWidget);
      expect(find.text('Pelanggan periode lalu'), findsOneWidget);
    },
  );

  testWidgets('ranking failure retries and handles an empty custom period', (
    tester,
  ) async {
    final repo = CustomerRepository();
    await pumpHome(tester, repo, 'owner');
    repo.fail = true;
    await choosePastRange(tester);
    expect(find.text('Peringkat belum bisa dimuat'), findsOneWidget);
    repo.fail = false;
    repo.rows.clear();
    await tapVisible(tester, find.text('Coba lagi'));
    expect(find.text('Belum ada pelanggan pada periode ini.'), findsOneWidget);
    expect(find.byKey(const ValueKey('customer-rank-1')), findsNothing);
  });

  testWidgets('ranking and history fit a small phone with enlarged text', (
    tester,
  ) async {
    final repo = CustomerRepository();
    for (final row in repo.rows) {
      if (row['phone'] == '08120001') {
        row['customer_name'] = 'Pelanggan dengan nama sangat panjang sekali';
      }
    }
    await pumpHome(
      tester,
      repo,
      'owner',
      size: const Size(320, 740),
      textScale: 1.5,
    );
    await showCard(tester);
    expect(tester.takeException(), isNull);
    await tapVisible(tester, find.byKey(const ValueKey('customer-rank-1')));
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('customer history reads all pages of receipts', (tester) async {
    final repo = CustomerRepository();
    repo.rows.clear();
    for (var i = 0; i < 61; i++) {
      repo.rows.add({
        ...sampleOrder(index: i, createdAt: repo.month.start.toIso8601String()),
        'customer_name': 'Pelanggan setia',
        'phone': '08120001',
        'notes': '',
      });
    }
    await pumpHome(tester, repo, 'owner');
    expect(repo.reads.map((r) => r.$2), [0, 1, 2]);
    repo.reads.clear();
    await tapVisible(tester, find.byKey(const ValueKey('customer-rank-1')));
    expect(repo.reads.map((r) => r.$2), [0, 1, 2]);
    expect(find.text('61 kunjungan'), findsOneWidget);
    expect(find.text('Total transaksi Rp5.185.000'), findsOneWidget);
  });

  testWidgets('date changes in full ranking carry back to the summary card', (
    tester,
  ) async {
    final repo = CustomerRepository();
    await pumpHome(tester, repo, 'owner');
    await tapVisible(tester, find.byKey(const ValueKey('all-customers')));
    await choosePastRange(tester);
    expect(find.text('Pelanggan periode lalu'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await showCard(tester);
    expect(find.text(pastLabel), findsOneWidget);
    expect(find.text('Pelanggan periode lalu'), findsOneWidget);
  });

  testWidgets(
    'history loading failure retries and removed receipts show an empty state',
    (tester) async {
      final repo = CustomerRepository();
      await pumpHome(tester, repo, 'owner');
      repo.fail = true;
      await tapVisible(tester, find.byKey(const ValueKey('customer-rank-1')));
      expect(find.text('Riwayat belum bisa dimuat'), findsOneWidget);
      repo.fail = false;
      repo.rows.clear();
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      expect(find.text('Belum ada nota'), findsOneWidget);
      expect(find.text('0 kunjungan'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

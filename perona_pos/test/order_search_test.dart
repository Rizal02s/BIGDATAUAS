import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perona_pos/domain.dart';
import 'package:perona_pos/order_filters.dart';

import 'home_page_test.dart' show pumpHome, capture, loadPreviewFonts;
import 'order_dates_test.dart' show openMonth, tapDay;
import 'order_quick_actions_test.dart'
    show QuickActionRepository, tapCardAction;
import 'wage_detail_test.dart' show tapVisible;

Json clone(Json row) => jsonDecode(jsonEncode(row)) as Json;

class SearchRepository extends QuickActionRepository {
  final reads = <(Period, int, String?)>[];
  late final List<Json> rows;
  bool failSearch = false;

  SearchRepository() {
    current['phone'] = '+62 812-3456-7890';
    current['items'][0]['status'] = 'Dikerjakan';
    rows = [current];
    for (final sample in [
      ('ready', 25, 'Sinta Dewi', 'Selesai', 30000),
      ('new', 26, 'Ayu Putri', 'Masuk', 0),
      ('picked', 27, 'Nadia Putri', 'Diambil', 90000),
    ]) {
      final row = clone(current);
      row['id'] = sample.$1;
      row['number'] = sample.$2;
      row['customer_name'] = sample.$3;
      row['phone'] = '0812000${sample.$2}';
      for (final item in row['items']) {
        item['status'] = sample.$4;
        item['worker_id'] = 'staff-b';
      }
      row['payments'] = [
        {
          'id': 'p-${sample.$1}',
          'amount': sample.$5,
          'method': 'Tunai',
          'voided_at': null,
          'paid_at': row['created_at'],
        },
        {
          'id': 'void-${sample.$1}',
          'amount': 90000,
          'method': 'QRIS',
          'voided_at': row['created_at'],
          'paid_at': row['created_at'],
        },
      ];
      rows.add(row);
    }
  }

  @override
  Future<List<Json>> orders(Period period, int page, {String? workerId}) async {
    reads.add((period, page, workerId));
    if (failSearch) throw StateError('Koneksi pencarian terputus.');
    final matching =
        rows
            .where(
              (row) =>
                  row['deleted_at'] == null &&
                  period.contains(
                    DateTime.parse(row['created_at'] as String),
                  ) &&
                  (workerId == null ||
                      (row['items'] as List).any(
                        (item) => item['worker_id'] == workerId,
                      )),
            )
            .toList()
          ..sort((a, b) => '${a['id']}'.compareTo('${b['id']}'));
    return matching.skip(page * 30).take(30).map(clone).toList();
  }

  @override
  Future<Json> order(String id) async {
    detailReads++;
    return clone(rows.firstWhere((row) => row['id'] == id));
  }
}

Future<void> enterQuery(WidgetTester tester, String value) async {
  final target = find.byKey(const ValueKey('order-search'));
  await tester.scrollUntilVisible(
    target,
    -300,
    maxScrolls: 90,
    scrollable: find.byType(Scrollable).first,
  );
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.15);
  await tester.pumpAndSettle();
  await tester.enterText(target, value);
  await tester.pumpAndSettle();
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pumpAndSettle();
}

Future<void> showResults(
  WidgetTester tester, {
  bool empty = false,
  bool failed = false,
}) async {
  final target =
      empty
          ? find.text('Tidak ada order yang cocok')
          : failed
          ? find.text('Pencarian belum bisa dimuat')
          : find.byKey(const ValueKey('order-result-count'));
  await tester.scrollUntilVisible(
    target,
    300,
    maxScrolls: 90,
    scrollable: find.byType(Scrollable).first,
  );
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.05);
  await tester.pumpAndSettle();
}

Future<void> chooseWork(WidgetTester tester, WorkFilter filter) async {
  await tapControl(tester, find.byType(DropdownButton<WorkFilter>));
  await tester.tap(find.text(filter.label).last);
  await tester.pumpAndSettle();
}

Future<void> choosePayment(WidgetTester tester, PaymentFilter filter) async {
  await tapControl(tester, find.byType(DropdownButton<PaymentFilter>));
  await tester.tap(find.text(filter.label).last);
  await tester.pumpAndSettle();
}

Future<void> tapControl(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    -300,
    maxScrolls: 90,
    scrollable: find.byType(Scrollable).first,
  );
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.2);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadPreviewFonts);

  testWidgets(
    'monthly search finds name phone and receipt number and resets to dates',
    (tester) async {
      final repo = SearchRepository();
      await openMonth(tester, repo, 'owner');
      await enterQuery(tester, 'rizAL');
      await showResults(tester);
      expect(find.byKey(const ValueKey('order-card-order-a')), findsOneWidget);
      expect(find.text('1 order ditemukan'), findsOneWidget);
      expect(find.byKey(const ValueKey('order-day-3')), findsNothing);
      final reads = repo.reads.length;
      await enterQuery(tester, '0812 3456');
      await showResults(tester);
      expect(find.byKey(const ValueKey('order-card-order-a')), findsOneWidget);
      expect(repo.reads.length, reads);
      await enterQuery(tester, '#25');
      await showResults(tester);
      expect(find.byKey(const ValueKey('order-card-ready')), findsOneWidget);
      expect(find.byKey(const ValueKey('order-card-order-a')), findsNothing);
      await capture(tester, 'order-search-results');
      await tapVisible(
        tester,
        find.byKey(const ValueKey('reset-order-filters')),
      );
      expect(find.byKey(const ValueKey('order-day-3')), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('order-search')))
            .controller!
            .text,
        isEmpty,
      );
    },
  );

  testWidgets(
    'work and payment combine with query and switching filters reuses loaded data',
    (tester) async {
      final repo = SearchRepository();
      await openMonth(tester, repo, 'owner');
      await choosePayment(tester, PaymentFilter.outstanding);
      await showResults(tester);
      expect(find.text('3 order ditemukan'), findsOneWidget);
      expect(find.byKey(const ValueKey('order-card-picked')), findsNothing);
      final reads = repo.reads.length;
      await chooseWork(tester, WorkFilter.ready);
      await showResults(tester);
      expect(find.text('1 order ditemukan'), findsOneWidget);
      expect(find.byKey(const ValueKey('order-card-ready')), findsOneWidget);
      expect(repo.reads.length, reads);
      await enterQuery(tester, 'Rizal');
      await showResults(tester, empty: true);
      expect(find.text('Tidak ada order yang cocok'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'search reads every page and finds an order outside the first thirty',
    (tester) async {
      final repo = SearchRepository();
      repo.rows.clear();
      for (var i = 0; i < 61; i++) {
        repo.rows.add({
          ...clone(repo.current),
          'id': 'order-${i.toString().padLeft(3, '0')}',
          'number': i + 100,
          'customer_name': i == 60 ? 'Customer terakhir' : 'Customer $i',
        });
      }
      await openMonth(tester, repo, 'owner');
      repo.reads.clear();
      await enterQuery(tester, 'terakhir');
      await showResults(tester);
      expect(repo.reads.map((read) => read.$2), [0, 1, 2]);
      expect(
        find.byKey(const ValueKey('order-card-order-060')),
        findsOneWidget,
      );
      await enterQuery(tester, 'Customer');
      await showResults(tester);
      expect(find.text('61 order ditemukan'), findsOneWidget);
      await tapVisible(tester, find.byKey(const ValueKey('search-next-page')));
      expect(find.text('Halaman 2 dari 3'), findsOneWidget);
      await enterQuery(tester, 'terakhir');
      await showResults(tester);
      expect(
        find.byKey(const ValueKey('order-card-order-060')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('search-next-page')), findsNothing);
    },
  );

  testWidgets(
    'technician search keeps assigned work and can switch all orders',
    (tester) async {
      final repo = SearchRepository();
      await openMonth(tester, repo, 'staff');
      await choosePayment(tester, PaymentFilter.outstanding);
      await showResults(tester);
      expect(find.text('1 order ditemukan'), findsOneWidget);
      expect(repo.reads.last.$3, 'staff-a');
      await tapVisible(tester, find.widgetWithText(ChoiceChip, 'Semua order'));
      await showResults(tester);
      expect(find.text('3 order ditemukan'), findsOneWidget);
      expect(repo.reads.last.$3, isNull);
    },
  );

  testWidgets('filtered status and payment refresh after quick actions', (
    tester,
  ) async {
    final repo = SearchRepository();
    await openMonth(tester, repo, 'owner');
    await enterQuery(tester, 'Rizal');
    await choosePayment(tester, PaymentFilter.outstanding);
    await showResults(tester);
    await tapCardAction(tester, 'payment-status');
    await tester.enterText(find.byType(TextFormField), '90000');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    await showResults(tester, empty: true);
    expect(find.byKey(const ValueKey('order-card-order-a')), findsNothing);
    expect(repo.paymentCalls, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('search failures retry and day detail can also search', (
    tester,
  ) async {
    final repo = SearchRepository();
    await openMonth(tester, repo, 'owner');
    await tapDay(tester, 3);
    repo.failSearch = true;
    await enterQuery(tester, '#24');
    await showResults(tester, failed: true);
    repo.failSearch = false;
    await tapVisible(tester, find.text('Coba lagi'));
    await showResults(tester);
    expect(find.byKey(const ValueKey('order-card-order-a')), findsOneWidget);
    expect(
      repo.reads.last.$1.end.difference(repo.reads.last.$1.start),
      const Duration(days: 1),
    );
  });

  testWidgets('admin search uses the same filters without requiring wages', (
    tester,
  ) async {
    final repo = SearchRepository();
    await openMonth(tester, repo, 'admin');
    await enterQuery(tester, '#25');
    await showResults(tester);
    expect(find.byKey(const ValueKey('order-card-ready')), findsOneWidget);
    expect(find.text('Ongkos'), findsNothing);
    expect(repo.reportReads, 0);
  });

  testWidgets(
    'search controls and results fit a small screen with large text',
    (tester) async {
      final repo = SearchRepository();
      await pumpHome(
        tester,
        repo,
        'owner',
        size: const Size(320, 740),
        textScale: 1.5,
      );
      await tester.tap(find.text('Order'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bulanan'));
      await tester.pumpAndSettle();
      await chooseWork(tester, WorkFilter.notPickedUp);
      await choosePayment(tester, PaymentFilter.outstanding);
      await enterQuery(tester, 'Sinta');
      await showResults(tester);
      expect(find.byKey(const ValueKey('order-card-ready')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

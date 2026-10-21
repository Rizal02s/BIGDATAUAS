import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perona_pos/domain.dart';

import 'home_page_test.dart'
    show DemoRepository, pumpHome, capture, loadPreviewFonts;
import 'report_data_test.dart' show sampleOrder;

class WageDetailRepository extends DemoRepository {
  final month = jakarta(DateTime.now());
  final reads = <(Period, int, String?)>[];
  final rows = <Json>[];
  bool failDetail = false;

  WageDetailRepository({int count = 2}) {
    final period = Period.forDate(month, 'month');
    for (var i = 0; i < count; i++) {
      final row = sampleOrder(
        index: i + 1,
        createdAt:
            (i == count - 1
                    ? period.end.subtract(const Duration(seconds: 1))
                    : period.start)
                .toIso8601String(),
      );
      (row['items'] as List).add({
        'name': 'Fast Clean',
        'quantity': 3,
        'labor_fee': 5000,
        'price': 10000,
        'worker_id': 'staff-a',
        'status': 'Masuk',
      });
      row['payments'] = [];
      row['notes'] = '';
      rows.add(row);
    }
    rows.add({
      ...sampleOrder(index: 90),
      'created_at':
          period.start.subtract(const Duration(seconds: 1)).toIso8601String(),
    });
    rows.add({
      ...sampleOrder(index: 91),
      'created_at': period.end.toIso8601String(),
    });
    rows.add({
      ...sampleOrder(index: 92),
      'created_at': period.start.toIso8601String(),
      'deleted_at': period.start.toIso8601String(),
    });
  }

  @override
  Future<List<Json>> orders(Period period, int page, {String? workerId}) async {
    reads.add((period, page, workerId));
    if (failDetail) throw StateError('Koneksi rincian terputus.');
    return rows.skip(page * 30).take(30).toList();
  }

  @override
  Future<Json> order(String id) async =>
      rows.firstWhere((row) => row['id'] == id);
}

Future<void> openWages(
  WidgetTester tester,
  WageDetailRepository repo, {
  String role = 'owner',
  bool monthly = true,
}) async {
  await pumpHome(tester, repo, role);
  await tester.tap(find.text('Ongkos'));
  await tester.pumpAndSettle();
  if (monthly) {
    await tester.tap(find.text('Bulanan'));
    await tester.pumpAndSettle();
  }
}

Future<void> tapVisible(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    200,
    maxScrolls: 80,
    scrollable: find.byType(Scrollable).first,
  );
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.4);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<DataTable> wageTable(WidgetTester tester) async {
  final target = find.byType(DataTable);
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  return tester.widget<DataTable>(target);
}

void main() {
  setUpAll(loadPreviewFonts);
  testWidgets(
    'total wage card opens monthly receipts in requested column order',
    (tester) async {
      final repo = WageDetailRepository();
      await openWages(tester, repo);
      await capture(tester, 'wage-summary-clickable');
      await tapVisible(tester, find.byKey(const ValueKey('team-wage-detail')));
      expect(find.text('Rincian ongkos tim'), findsOneWidget);
      expect(repo.reads.last.$3, isNull);
      final period = Period.forDate(repo.month, 'month');
      expect(repo.reads.last.$1.start, period.start);
      expect(repo.reads.last.$1.end, period.end);
      expect(find.text('Rp90.000'), findsOneWidget);
      await capture(tester, 'wage-notes-team');
      final table = await wageTable(tester);
      await capture(tester, 'wage-notes-table');
      expect(table.columns.map((column) => (column.label as Text).data), [
        'No',
        'Tanggal masuk',
        'Nama customer',
        'Jenis order',
        'Total ongkos per nota',
      ]);
      expect(table.rows.length, 2);
      expect(find.textContaining('Customer 90'), findsNothing);
      expect(find.textContaining('Customer 91'), findsNothing);
      expect(find.textContaining('Customer 92'), findsNothing);
      final first = table.rows.first.cells;
      expect(((first.first.child as SizedBox).child as Text).data, '1');
      expect(
        ((first[1].child as SizedBox).child as Text).data,
        '01/${repo.month.month.toString().padLeft(2, '0')}/${repo.month.year}',
      );
      expect(
        ((first[3].child as SizedBox).child as Text).data,
        contains('Fast Clean × 3'),
      );
      expect(((first[4].child as SizedBox).child as Text).data, 'Rp45.000');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'technician row groups only that technicians work into one row per receipt',
    (tester) async {
      final repo = WageDetailRepository();
      await openWages(tester, repo);
      await tapVisible(
        tester,
        find.byKey(const ValueKey('worker-wage-staff-a')),
      );
      expect(find.text('Ongkos Dina'), findsOneWidget);
      expect(repo.reads.last.$3, 'staff-a');
      expect(find.text('Rp70.000'), findsOneWidget);
      final table = await wageTable(tester);
      expect(table.rows.length, 2);
      expect(find.textContaining('Perawatan sepatu kulit'), findsNothing);
      expect(
        ((table.rows.first.cells[4].child as SizedBox).child as Text).data,
        'Rp35.000',
      );
    },
  );

  testWidgets('own wage amount opens personal receipt details', (tester) async {
    final repo = WageDetailRepository();
    await openWages(tester, repo, role: 'staff');
    await tapVisible(tester, find.byKey(const ValueKey('own-wage-detail')));
    expect(find.text('Ongkos Dina'), findsOneWidget);
    expect(repo.reads.last.$3, 'staff-a');
    expect((await wageTable(tester)).rows.length, 2);
  });

  testWidgets('monthly detail loads every page of receipts', (tester) async {
    final repo = WageDetailRepository(count: 61);
    await openWages(tester, repo);
    repo.reads.clear();
    await tapVisible(tester, find.byKey(const ValueKey('team-wage-detail')));
    expect(repo.reads.map((read) => read.$2), [0, 1, 2]);
    expect((await wageTable(tester)).rows.length, 61);
  });

  testWidgets('empty or failed wage details can recover by retrying', (
    tester,
  ) async {
    final repo = WageDetailRepository(count: 0);
    await openWages(tester, repo);
    repo.failDetail = true;
    await tapVisible(tester, find.byKey(const ValueKey('team-wage-detail')));
    expect(find.text('Rincian belum bisa dimuat'), findsOneWidget);
    repo.failDetail = false;
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada pekerjaan'), findsOneWidget);
    expect(find.byType(DataTable), findsNothing);
  });

  testWidgets(
    'receipt row opens original order and refreshes after returning',
    (tester) async {
      final repo = WageDetailRepository();
      await openWages(tester, repo);
      await tapVisible(tester, find.byKey(const ValueKey('team-wage-detail')));
      await wageTable(tester);
      await tapVisible(tester, find.text('Customer 1\nNota #1'));
      expect(find.text('Detail order'), findsOneWidget);
      repo.rows.removeWhere((row) => row['id'] == 'order-1');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect((await wageTable(tester)).rows.length, 1);
      expect(find.textContaining('Customer 1\n'), findsNothing);
    },
  );

  testWidgets(
    'table scrolls horizontally on a small phone with enlarged text',
    (tester) async {
      final repo = WageDetailRepository();
      await pumpHome(
        tester,
        repo,
        'owner',
        size: const Size(320, 740),
        textScale: 1.5,
      );
      await tester.tap(find.text('Ongkos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bulanan'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const ValueKey('team-wage-detail')));
      await wageTable(tester);
      final horizontal = find.byWidgetPredicate(
        (w) =>
            w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
      );
      await tester.drag(horizontal, const Offset(-900, 0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perona_pos/domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_page_test.dart' show DemoRepository, pumpHome;
import 'order_dates_test.dart' show openMonth, tapDay;

class DeletionRepository extends DemoRepository {
  final month = jakarta(DateTime.now());
  final rows = <Json>[];
  final deleted = <String>[];
  final reasons = <String>[];
  final pagesRead = <int>[];
  bool failDelete = false, failLoad = false;
  Completer<void>? pendingDelete;
  int? failAfter;

  DeletionRepository({int count = 2}) {
    for (var i = 0; i < count; i++) {
      rows.add({
        'id': 'order-$i',
        'version': 3,
        'number': i + 1,
        'customer_name': 'Pelanggan ${i + 1}',
        'created_at':
            DateTime.utc(month.year, month.month, 3, 3).toIso8601String(),
        'total': 30000,
        'items': [
          {'name': 'Deep Clean', 'quantity': 1, 'status': 'Masuk'},
        ],
        'payments': [],
      });
    }
  }

  @override
  Future<List<Json>> orders(Period period, int page, {String? workerId}) async {
    if (failLoad) throw const AuthException('Gagal memuat order.');
    pagesRead.add(page);
    return rows
        .where(
          (row) => period.contains(DateTime.parse(row['created_at'] as String)),
        )
        .skip(page * 30)
        .take(30)
        .toList();
  }

  @override
  Future<Json> order(String id) async =>
      Map.of(rows.firstWhere((r) => r['id'] == id));

  @override
  Future<Map<int, int>> orderDayCounts(
    DateTime month, {
    String? workerId,
  }) async {
    final counts = <int, int>{};
    for (final row in rows) {
      final day = jakarta(DateTime.parse(row['created_at'] as String)).day;
      counts.update(day, (count) => count + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  @override
  Future<void> delete(Json order, String reason) async {
    if (pendingDelete != null) await pendingDelete!.future;
    if (failDelete || deleted.length == failAfter) {
      throw const AuthException('Order berubah. Muat ulang terlebih dahulu.');
    }
    expect(order['version'], 3);
    deleted.add(order['id'] as String);
    reasons.add(reason);
    rows.removeWhere((r) => r['id'] == order['id']);
  }
}

Future<void> confirmDeletion(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Ya'));
  await tester.pumpAndSettle();
}

Future<void> openDayDeletion(
  WidgetTester tester,
  DeletionRepository repo,
) async {
  await openMonth(tester, repo, 'owner');
  await tapDay(tester, 3);
  await tester.tap(find.text('Hapus semua order tanggal ini'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'single order needs only yes or no and refreshes the selected day',
    (tester) async {
      final repo = DeletionRepository();
      await openMonth(tester, repo, 'owner');
      await tapDay(tester, 3);
      await tester.tap(find.byKey(const ValueKey('delete-order-order-0')));
      await tester.pumpAndSettle();
      expect(find.text('Detail order'), findsNothing);
      expect(find.textContaining('order #1 · Pelanggan 1'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('Tidak'), findsOneWidget);
      expect(repo.deleted, isEmpty);
      await confirmDeletion(tester);
      expect(repo.deleted, ['order-0']);
      expect(repo.reasons, ['Dihapus oleh owner.']);
      expect(find.text('Pelanggan 1'), findsNothing);
      expect(find.text('Pelanggan 2'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('1 order'), findsOneWidget);
    },
  );

  testWidgets('bulk deletion snapshots all pages and preserves other dates', (
    tester,
  ) async {
    final repo = DeletionRepository(count: 31);
    repo.rows.add({
      ...repo.rows.first,
      'id': 'other-day',
      'created_at':
          DateTime.utc(
            repo.month.year,
            repo.month.month,
            4,
            3,
          ).toIso8601String(),
    });
    await openDayDeletion(tester, repo);
    expect(repo.pagesRead, contains(1));
    expect(find.textContaining('31 order pada tanggal ini'), findsOneWidget);
    await confirmDeletion(tester);
    expect(repo.deleted.length, 31);
    expect(repo.rows.single['id'], 'other-day');
    expect(find.text('Belum ada order pada tanggal ini'), findsOneWidget);
  });

  testWidgets(
    'monthly delete action confirms correct WIB date and can be cancelled',
    (tester) async {
      final repo = DeletionRepository();
      await openMonth(tester, repo, 'owner');
      final target = find.byKey(const ValueKey('delete-order-day-3'));
      await tester.scrollUntilVisible(
        target,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(tester.element(target), alignment: 0.4);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(find.textContaining('2 order pada tanggal ini'), findsOneWidget);
      expect(
        find.text(
          'Tanggal 03/${repo.month.month.toString().padLeft(2, '0')}/${repo.month.year} · WIB',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Tidak'));
      await tester.pumpAndSettle();
      expect(repo.deleted, isEmpty);
      expect(find.byKey(const ValueKey('order-day-3')), findsOneWidget);
    },
  );

  testWidgets(
    'bulk deletion accepts unpaid, partially paid and fully paid orders',
    (tester) async {
      final repo = DeletionRepository(count: 31);
      repo.rows.last['payments'] = [
        {'amount': 30000, 'voided_at': null},
      ];
      repo.rows.first['payments'] = [
        {'amount': 10000, 'voided_at': null},
      ];
      await openDayDeletion(tester, repo);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.textContaining('koreksi pembayaran'), findsNothing);
      expect(repo.deleted, isEmpty);
      await confirmDeletion(tester);
      expect(repo.deleted.length, 31);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets(
    'voided payments allow deletion and partial failure is explicit',
    (tester) async {
      final repo = DeletionRepository(count: 3)..failAfter = 1;
      repo.rows.first['payments'] = [
        {'amount': 30000, 'voided_at': '2026-10-03T04:00:00Z'},
      ];
      await openDayDeletion(tester, repo);
      await confirmDeletion(tester);
      expect(repo.deleted, ['order-0']);
      expect(
        find.textContaining('1/3 order terkonfirmasi dihapus'),
        findsOneWidget,
      );
      expect(find.textContaining('Order berubah'), findsOneWidget);
      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();
      expect(find.text('Pelanggan 1'), findsNothing);
      expect(find.text('Pelanggan 2'), findsOneWidget);
    },
  );

  testWidgets('loading failures can retry without deleting anything', (
    tester,
  ) async {
    final repo = DeletionRepository();
    await openMonth(tester, repo, 'owner');
    await tapDay(tester, 3);
    repo.failLoad = true;
    await tester.tap(find.text('Hapus semua order tanggal ini'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Gagal memuat order'), findsOneWidget);
    expect(repo.deleted, isEmpty);
    repo.failLoad = false;
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    await confirmDeletion(tester);
    expect(repo.deleted.length, 2);
  });

  testWidgets(
    'deletion prevents duplicate submission and back navigation while running',
    (tester) async {
      final repo = DeletionRepository()..pendingDelete = Completer<void>();
      await openDayDeletion(tester, repo);
      final button = find.widgetWithText(FilledButton, 'Ya');
      await tester.tap(button);
      await tester.pump();
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(AlertDialog), findsOneWidget);
      repo.pendingDelete!.complete();
      await tester.pumpAndSettle();
      expect(repo.deleted, ['order-0', 'order-1']);
    },
  );

  for (final role in ['staff', 'technician', 'admin']) {
    testWidgets('$role has no deletion controls', (tester) async {
      final repo = DeletionRepository();
      await openMonth(tester, repo, role);
      expect(find.byKey(const ValueKey('delete-order-day-3')), findsNothing);
      await tapDay(tester, 3);
      expect(find.text('Hapus semua order tanggal ini'), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });
  }

  testWidgets('owner deletion controls fit narrow screens with large text', (
    tester,
  ) async {
    final repo = DeletionRepository();
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
    await tapDay(tester, 3);
    await tester.tap(find.text('Hapus semua order tanggal ini'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

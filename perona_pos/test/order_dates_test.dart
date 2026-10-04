import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:perona_pos/domain.dart';
import 'package:perona_pos/repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_page_test.dart'
    show DemoRepository, pumpHome, capture, loadPreviewFonts;
import 'order_detail_test.dart' show DetailRepository;

class DateRepository extends DetailRepository {
  final month = jakarta(DateTime.now());
  final countFilters = <String?>[];
  final dayRequests = <(Period, int, String?)>[];
  bool failDay = false;
  bool many = false;
  int countReads = 0;

  @override
  Future<Map<int, int>> orderDayCounts(
    DateTime month, {
    String? workerId,
  }) async {
    countReads++;
    countFilters.add(workerId);
    return {
      3:
          many
              ? 31
              : workerId == null
              ? 2
              : 1,
    };
  }

  @override
  Future<List<Json>> orders(Period period, int page, {String? workerId}) async {
    dayRequests.add((period, page, workerId));
    if (failDay) throw const AuthException('Koneksi pengujian terputus.');
    final rows = await super.orders(period, page, workerId: workerId);
    final matching =
        rows
            .map(
              (row) => {
                ...row,
                'created_at':
                    DateTime.utc(
                      month.year,
                      month.month,
                      3,
                      3,
                    ).toIso8601String(),
              },
            )
            .where(
              (row) =>
                  period.contains(DateTime.parse(row['created_at'] as String)),
            )
            .toList();
    if (!many || matching.isEmpty) return matching;
    return List.generate(
      31,
      (i) => {
        ...matching.first,
        'id': 'order-$i',
        'number': i + 1,
        'customer_name': 'Pelanggan ${i + 1}',
      },
    ).skip(page * 30).take(30).toList();
  }
}

Future<void> openMonth(
  WidgetTester tester,
  DemoRepository repo,
  String role,
) async {
  await pumpHome(tester, repo, role);
  await tester.tap(find.text('Order'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Bulanan'));
  await tester.pumpAndSettle();
}

Future<void> tapDay(WidgetTester tester, int day) async {
  final target = find.byKey(ValueKey('order-day-$day'));
  await tester.scrollUntilVisible(
    target,
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.4);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadPreviewFonts);

  test(
    'monthly counts read every page with WIB bounds and worker filter',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          requests.add(request);
          final rows =
              requests.length == 1
                  ? List.generate(
                    500,
                    (i) => {'id': '$i', 'created_at': '2028-02-01T16:59:59Z'},
                  )
                  : [
                    {'id': '500', 'created_at': '2028-02-01T17:00:00Z'},
                    {'id': '501', 'created_at': '2028-02-29T16:59:59Z'},
                  ];
          return http.Response(jsonEncode(rows), 200, request: request);
        }),
      );
      addTearDown(client.dispose);
      final counts = await Repository(
        client,
      ).orderDayCounts(DateTime(2028, 2), workerId: 'staff-a');
      expect(counts, {1: 500, 2: 1, 29: 1});
      expect(requests.length, 2);
      final params = requests.first.url.queryParametersAll;
      expect(params['created_at'], [
        'gte.2028-01-31T17:00:00.000Z',
        'lt.2028-02-29T17:00:00.000Z',
      ]);
      expect(params['deleted_at'], ['is.null']);
      expect(params['items']!.single, contains('staff-a'));
      expect(params['select'], ['id,created_at']);
      expect(requests.last.url.queryParameters['offset'], '500');
    },
  );

  testWidgets(
    'month shows dates, opens that day, detail, and refreshes counts on return',
    (tester) async {
      final repo = DateRepository();
      await openMonth(tester, repo, 'owner');
      expect(find.text('Andi Pratama'), findsNothing);
      expect(find.text('Tanggal order'), findsOneWidget);
      await capture(tester, 'order-dates');
      await tapDay(tester, 3);
      expect(find.text('Andi Pratama'), findsOneWidget);
      expect(
        repo.dayRequests.last.$1.start,
        DateTime.utc(repo.month.year, repo.month.month, 2, 17),
      );
      await capture(tester, 'orders-on-date');
      await tester.tap(find.text('Andi Pratama'));
      await tester.pumpAndSettle();
      expect(find.text('Detail order'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Tanggal order'),
        -180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Tanggal order'), findsOneWidget);
      expect(repo.countReads, 2);
    },
  );

  testWidgets('last calendar date and empty days are available', (
    tester,
  ) async {
    final repo = DateRepository();
    await openMonth(tester, repo, 'owner');
    final last = DateTime.utc(repo.month.year, repo.month.month + 1, 0).day;
    await tapDay(tester, last);
    expect(find.text('Belum ada order pada tanggal ini'), findsOneWidget);
    expect(
      repo.dayRequests.last.$1.end,
      DateTime.utc(
        repo.month.year,
        repo.month.month + 1,
        1,
      ).subtract(const Duration(hours: 7)),
    );
  });

  testWidgets('staff date counts and daily orders keep personal filter', (
    tester,
  ) async {
    final repo = DateRepository();
    await openMonth(tester, repo, 'staff');
    expect(repo.countFilters.last, 'staff-a');
    await tapDay(tester, 3);
    expect(repo.dayRequests.last.$3, 'staff-a');
    expect(find.text('Sinta Dewi'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Semua order'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('Semua order')),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Semua order'));
    await tester.pumpAndSettle();
    expect(repo.countFilters.last, isNull);
    await tapDay(tester, 3);
    expect(repo.dayRequests.last.$3, isNull);
  });

  testWidgets('daily loading failure can be retried', (tester) async {
    final repo = DateRepository();
    await openMonth(tester, repo, 'owner');
    repo.failDay = true;
    await tapDay(tester, 3);
    expect(find.text('Data belum bisa dimuat'), findsOneWidget);
    repo.failDay = false;
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.text('Andi Pratama'), findsOneWidget);
  });

  testWidgets('busy day retains orders beyond the first page', (tester) async {
    final repo = DateRepository()..many = true;
    await openMonth(tester, repo, 'owner');
    await tapDay(tester, 3);
    await tester.scrollUntilVisible(
      find.text('Berikutnya'),
      500,
      maxScrolls: 80,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('Berikutnya')),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Berikutnya'));
    await tester.pumpAndSettle();
    expect(repo.dayRequests.last.$2, 1);
    expect(find.text('Pelanggan 31'), findsOneWidget);
    await tester.tap(find.text('Sebelumnya'));
    await tester.pumpAndSettle();
    expect(repo.dayRequests.last.$2, 0);
  });

  testWidgets('date rows fit a small phone with enlarged text', (tester) async {
    final repo = DateRepository();
    await pumpHome(
      tester,
      repo,
      'owner',
      size: const Size(360, 800),
      textScale: 1.5,
    );
    await tester.tap(find.text('Order'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bulanan'));
    await tester.pumpAndSettle();
    await tapDay(tester, 3);
    expect(find.text('Semua order · WIB'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

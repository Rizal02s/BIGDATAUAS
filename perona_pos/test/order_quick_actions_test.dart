import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:perona_pos/domain.dart';
import 'package:perona_pos/main.dart' show errorText;
import 'package:perona_pos/repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_page_test.dart'
    show DemoRepository, pumpHome, capture, loadPreviewFonts;
import 'order_dates_test.dart' show openMonth, tapDay;

class QuickActionRepository extends DemoRepository {
  final now = jakarta(DateTime.now());
  late Json current = {
    'id': 'order-a',
    'version': 1,
    'number': 24,
    'customer_name': 'Rizal',
    'phone': '',
    'notes': '',
    'discount': 0,
    'total': 90000,
    'created_at': DateTime.utc(now.year, now.month, 3, 3).toIso8601String(),
    'items': [
      {
        'id': 'item-a',
        'name': 'Deep Clean',
        'quantity': 2,
        'price': 30000,
        'worker_id': 'staff-a',
        'status': 'Masuk',
      },
      {
        'id': 'item-b',
        'name': 'Fast Clean',
        'quantity': 1,
        'price': 30000,
        'worker_id': 'staff-b',
        'status': 'Masuk',
      },
    ],
    'payments': <Json>[],
    'order_photos': [],
  };
  final statusCalls = <Json>[];
  final paymentCalls = <Json>[];
  bool losePaymentResponse = false, failStatus = false;
  Completer<void>? paymentGate;
  int detailReads = 0;

  @override
  Future<List<Json>> orders(
    Period period,
    int page, {
    String? workerId,
  }) async => page == 0 ? [jsonDecode(jsonEncode(current)) as Json] : [];

  @override
  Future<Map<int, int>> orderDayCounts(
    DateTime month, {
    String? workerId,
  }) async => {3: 1};

  @override
  Future<Json> order(String id) async {
    detailReads++;
    return jsonDecode(jsonEncode(current)) as Json;
  }

  @override
  Future<void> updateOrderStatuses(
    String orderId,
    int version,
    List<Json> statuses,
  ) async {
    statusCalls.add({'id': orderId, 'version': version, 'statuses': statuses});
    if (failStatus) {
      throw const PostgrestException(
        message: 'Order telah berubah di HP lain.',
      );
    }
    for (final item in current['items'] as List) {
      final change =
          statuses.where((change) => change['id'] == item['id']).firstOrNull;
      if (change != null) item['status'] = change['status'];
    }
    current['version'] = version + 1;
  }

  @override
  Future<void> pay(
    String paymentId,
    String orderId,
    int amount,
    String method, {
    DateTime? paidAt,
  }) async {
    final payment = {
      'id': paymentId,
      'amount': amount,
      'method': method,
      'paid_at': (paidAt ?? DateTime.now().toUtc()).toIso8601String(),
      'voided_at': null,
    };
    paymentCalls.add({
      ...payment,
      'order_id': orderId,
      'selected_date': paidAt,
    });
    if (paymentGate != null) await paymentGate!.future;
    final payments = current['payments'] as List;
    if (!payments.any((p) => p['id'] == paymentId)) payments.add(payment);
    if (losePaymentResponse) {
      losePaymentResponse = false;
      throw Exception('Respons pembayaran terputus.');
    }
  }
}

Future<void> tapCardAction(WidgetTester tester, String action) async {
  final target = find.byKey(ValueKey('$action-order-a'));
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

Future<void> openOrders(
  WidgetTester tester,
  QuickActionRepository repo, {
  String role = 'owner',
}) async {
  await pumpHome(tester, repo, role);
  await tester.tap(find.text('Order'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadPreviewFonts);

  testWidgets(
    'day card updates all service statuses and refreshes immediately',
    (tester) async {
      final repo = QuickActionRepository();
      await openMonth(tester, repo, 'owner');
      await tapDay(tester, 3);
      await capture(tester, 'order-quick-actions');
      await tapCardAction(tester, 'work-status');
      expect(find.text('Ubah pengerjaan'), findsOneWidget);
      expect(find.text('Detail order'), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Selesai'));
      await tester.pumpAndSettle();
      await capture(tester, 'order-quick-status');
      await tester.tap(find.text('Simpan status'));
      await tester.pumpAndSettle();
      expect(repo.statusCalls.single['version'], 1);
      expect(repo.statusCalls.single['statuses'], [
        {'id': 'item-a', 'status': 'Selesai'},
        {'id': 'item-b', 'status': 'Selesai'},
      ]);
      expect(find.text('Selesai'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'personal card only updates assigned services and cancel writes nothing',
    (tester) async {
      final repo = QuickActionRepository();
      await openOrders(tester, repo, role: 'staff');
      await tapCardAction(tester, 'work-status');
      expect(find.text('Deep Clean × 2'), findsOneWidget);
      expect(find.text('Fast Clean × 1'), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Diambil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(repo.statusCalls, isEmpty);
      await tapCardAction(tester, 'work-status');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Diambil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simpan status'));
      await tester.pumpAndSettle();
      expect(repo.statusCalls.single['statuses'], [
        {'id': 'item-a', 'status': 'Diambil'},
      ]);
      expect((repo.current['items'] as List).last['status'], 'Masuk');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('one service can change on a narrow screen with large text', (
    tester,
  ) async {
    final repo = QuickActionRepository();
    await pumpHome(
      tester,
      repo,
      'admin',
      size: const Size(320, 740),
      textScale: 1.5,
    );
    await tester.tap(find.text('Order'));
    await tester.pumpAndSettle();
    await tapCardAction(tester, 'work-status');
    final field = find.byKey(const ValueKey('item-status-item-a-Masuk'));
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selesai').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan status'));
    await tester.pumpAndSettle();
    expect(repo.statusCalls.single['statuses'], [
      {'id': 'item-a', 'status': 'Selesai'},
    ]);
    expect((repo.current['items'] as List).last['status'], 'Masuk');
    expect(tester.takeException(), isNull);
  });

  testWidgets('conflicted status stays open and reload uses the new version', (
    tester,
  ) async {
    final repo = QuickActionRepository()..failStatus = true;
    await openOrders(tester, repo);
    await tapCardAction(tester, 'work-status');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Dikerjakan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan status'));
    await tester.pumpAndSettle();
    expect(find.text('Order telah berubah di HP lain.'), findsOneWidget);
    repo.failStatus = false;
    repo.current['version'] = 5;
    await tester.tap(find.text('Muat ulang'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Selesai'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan status'));
    await tester.pumpAndSettle();
    expect(repo.statusCalls.last['version'], 5);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'card records partial and later full payments with their actual dates',
    (tester) async {
      final repo = QuickActionRepository();
      await openMonth(tester, repo, 'admin');
      await tapDay(tester, 3);
      await tapCardAction(tester, 'payment-status');
      await tester.enterText(find.byType(TextFormField), '30000');
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(find.text('DP'), findsOneWidget);
      expect(repo.paymentCalls.single['selected_date'], isNull);
      await tapCardAction(tester, 'payment-status');
      expect(find.text('Sisa tagihan Rp60.000'), findsOneWidget);
      expect(find.text('Riwayat pembayaran'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        '60000',
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('QRIS').last);
      await tester.pumpAndSettle();
      await capture(tester, 'order-quick-payment');
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(find.text('Lunas'), findsOneWidget);
      expect(repo.paymentCalls.last['method'], 'QRIS');
      expect((repo.current['payments'] as List), hasLength(2));
      await tapCardAction(tester, 'payment-status');
      expect(find.text('Pembayaran lunas'), findsOneWidget);
      expect(find.text('Simpan'), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'payment validates balance, prevents double tap and retries the same receipt',
    (tester) async {
      final repo = QuickActionRepository()..losePaymentResponse = true;
      await openOrders(tester, repo);
      await tapCardAction(tester, 'payment-status');
      await tester.enterText(find.byType(TextFormField), '90001');
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(repo.paymentCalls, isEmpty);
      await tester.enterText(find.byType(TextFormField), '30000');
      repo.paymentGate = Completer<void>();
      await tester.tap(find.text('Simpan'));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Menyimpan…'),
            )
            .onPressed,
        isNull,
      );
      repo.paymentGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Coba lagi'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField)).enabled,
        false,
      );
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      expect(repo.paymentCalls, hasLength(2));
      expect(repo.paymentCalls.first['id'], repo.paymentCalls.last['id']);
      expect(repo.paymentCalls.last['amount'], 30000);
      expect(repo.current['payments'], hasLength(1));
      expect(find.text('DP'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'status RPC sends only status IDs and version; missing migration is actionable',
    () async {
      late http.Request captured;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            'null',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      await Repository(client).updateOrderStatuses('order-a', 7, [
        {'id': 'item-a', 'status': 'Selesai'},
      ]);
      expect(captured.url.path, endsWith('/rpc/update_order_statuses'));
      expect(jsonDecode(captured.body), {
        'p_id': 'order-a',
        'p_version': 7,
        'p_statuses': [
          {'id': 'item-a', 'status': 'Selesai'},
        ],
      });
      expect(
        errorText(
          const PostgrestException(
            code: 'PGRST202',
            message: 'update_order_statuses missing',
          ),
        ),
        contains('006_quick_order_status.sql'),
      );
    },
  );
}

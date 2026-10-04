import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:perona_pos/domain.dart';
import 'package:perona_pos/repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_page_test.dart' show pumpHome, capture, loadPreviewFonts;
import 'order_detail_test.dart' show DetailRepository;
import 'order_editor_test.dart' show openEditor, addService;
import 'order_submission_test.dart' show SubmissionRepository;

class AdminSubmissionRepository extends SubmissionRepository {
  Json? savedDraft;
  AdminSubmissionRepository() {
    accessRole = 'admin';
  }
  @override
  String get userId => 'admin-a';
  @override
  Future<List<Json>> services() async =>
      (await super.services())
          .map(
            (service) => {...service, 'orderable': true}..remove('labor_fee'),
          )
          .toList();
  @override
  Future<void> saveOrder(Json order) async {
    savedDraft = order;
    await super.saveOrder(order);
  }
}

void main() {
  setUpAll(loadPreviewFonts);

  test(
    'admin repository only uses redacted RPCs and blocks financial report requests',
    () async {
      final calls = <String>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          final endpoint = request.url.path.split('/').last;
          calls.add(endpoint);
          final Object response = switch (endpoint) {
            'service_catalog' => [
              {'id': 'service', 'price': 30000, 'orderable': true},
            ],
            'order_list' => [
              {'id': 'order', 'items': []},
            ],
            'order_detail' => {'id': 'order', 'items': []},
            'order_day_counts' => {'3': 32},
            _ => throw StateError('Unexpected raw read: ${request.url.path}'),
          };
          return http.Response(
            jsonEncode(response),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final repo = Repository(client)..accessRole = 'admin';
      expect((await repo.services()).single.containsKey('labor_fee'), false);
      expect(
        (await repo.orders(
          Period.forDate(DateTime(2026, 10, 3), 'day'),
          0,
        )).single['id'],
        'order',
      );
      expect((await repo.order('order')).containsKey('labor_total'), false);
      expect(await repo.orderDayCounts(DateTime(2026, 10)), {3: 32});
      await expectLater(
        repo.report(Period.forDate(DateTime(2026, 10), 'month')),
        throwsStateError,
      );
      expect(calls, [
        'service_catalog',
        'order_list',
        'order_detail',
        'order_day_counts',
      ]);
    },
  );

  testWidgets(
    'admin can select a service, assign a technician, and save QRIS without wage rates',
    (tester) async {
      final repo = AdminSubmissionRepository();
      await openEditor(tester, repo);
      await tester.enterText(
        find.byType(TextFormField).first,
        'Pelanggan admin',
      );
      expect(
        find.textContaining(RegExp('ongkos', caseSensitive: false)),
        findsNothing,
      );
      await addService(tester);
      expect(
        find.textContaining(RegExp('ongkos', caseSensitive: false)),
        findsNothing,
      );
      await capture(tester, 'admin-order-form');
      await tester.scrollUntilVisible(
        find.widgetWithText(ChoiceChip, 'QRIS'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(find.widgetWithText(ChoiceChip, 'QRIS')),
        alignment: 0.3,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'QRIS'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Simpan order'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Simpan order'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simpan order'));
      await tester.pumpAndSettle();
      expect(repo.saves, 1);
      expect(repo.savedDraft!['items'][0]['worker_id'], 'staff-a');
      expect(repo.receipts.values.single['amount'], 30000);
      expect(find.text('Buat order pengujian'), findsOneWidget);
    },
  );

  testWidgets('admin detail hides all wage figures and owner corrections', (
    tester,
  ) async {
    final repo = DetailRepository();
    await pumpHome(tester, repo, 'admin');
    await tester.tap(find.text('Order'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Andi Pratama'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Andi Pratama'));
    await tester.pumpAndSettle();
    expect(find.text('Detail order'), findsOneWidget);
    expect(
      find.textContaining(RegExp('ongkos', caseSensitive: false)),
      findsNothing,
    );
    expect(find.text('Hapus order'), findsNothing);
    expect(find.byTooltip('Koreksi salah input'), findsNothing);
    expect(find.text('Edit order'), findsOneWidget);
    await capture(tester, 'admin-order-detail');
  });
}

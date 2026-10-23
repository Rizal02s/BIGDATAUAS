import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:perona_pos/domain.dart';
import 'package:perona_pos/main.dart';
import 'package:perona_pos/repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_page_test.dart' show capture, loadPreviewFonts;
import 'order_editor_test.dart' show openEditor, addService;
import 'order_submission_test.dart' show SubmissionRepository, draft;

class LookupRepository extends SubmissionRepository {
  final queries = <String>[];
  final pending = <String, Completer<List<Json>>>{};
  List<Json> suggestions = List.generate(
    7,
    (i) => {
      'identity': 'phone:62812345000$i',
      'customer_name': 'Rizky ${i + 1}',
      'phone': '0812345000$i',
      'last_visit': '2026-10-19T17:30:00Z',
      'visits': i + 1,
    },
  );
  bool failLookup = false;
  @override
  Future<List<Json>> customerSuggestions(String query) async {
    queries.add(query);
    if (failLookup) {
      throw const PostgrestException(
        code: 'PGRST202',
        message: 'Missing customer_suggestions',
      );
    }
    if (pending.containsKey(query)) return pending[query]!.future;
    return suggestions;
  }
}

Future<void> typeQuery(
  WidgetTester tester,
  String query, {
  String field = 'name',
  bool wait = true,
}) async {
  final target = find.byKey(
    ValueKey(field == 'name' ? 'order-customer-name' : 'order-customer-phone'),
  );
  await tester.scrollUntilVisible(
    target,
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.enterText(target, query);
  await tester.pump();
  if (wait) {
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }
}

Future<void> saveOrder(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Simpan order'),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(find.text('Simpan order'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Simpan order'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadPreviewFonts);
  test(
    'Repository only queries 2+ characters and limits safe result projection to five',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((r) async {
          requests.add(r);
          return http.Response(
            jsonEncode(
              List.generate(
                7,
                (i) => {'identity': '$i', 'customer_name': 'Customer $i'},
              ),
            ),
            200,
            headers: {'content-type': 'application/json'},
            request: r,
          );
        }),
      );
      addTearDown(client.dispose);
      final repo = Repository(client);
      expect(await repo.customerSuggestions(' R '), isEmpty);
      expect(requests, isEmpty);
      expect(await repo.customerSuggestions('  Rizky  '), hasLength(5));
      expect(requests.single.url.path, endsWith('customer_suggestions'));
      expect(jsonDecode(requests.single.body), {'p_query': 'Rizky'});
      expect(
        errorText(
          const PostgrestException(
            code: 'PGRST202',
            message: 'Missing customer_suggestions',
          ),
        ),
        contains('011_customer_suggestions.sql'),
      );
    },
  );

  testWidgets(
    'Choosing customer fills both fields and saves one new note without extra lookup visits',
    (tester) async {
      final repo = LookupRepository();
      await openEditor(tester, repo);
      expect(repo.queries, isEmpty);
      await typeQuery(tester, 'Riz');
      expect(find.text('Rizky 1'), findsOneWidget);
      expect(find.text('Rizky 5'), findsOneWidget);
      expect(find.text('Rizky 6'), findsNothing);
      expect(find.textContaining('20/10/2026'), findsWidgets);
      expect(repo.saves, 0);
      await Scrollable.ensureVisible(
        tester.element(find.byKey(const ValueKey('order-customer-name'))),
        alignment: 0.05,
      );
      await tester.pumpAndSettle();
      await capture(tester, 'customer-suggestions');
      await tester.ensureVisible(find.text('Rizky 2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rizky 2'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('order-customer-name')),
            )
            .controller!
            .text,
        'Rizky 2',
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('order-customer-phone')),
            )
            .controller!
            .text,
        '08123450001',
      );
      expect(find.text('Pilih pelanggan lama'), findsNothing);
      await addService(tester);
      await saveOrder(tester);
      expect(repo.saves, 1);
      expect(repo.savedDraft!['customer_name'], 'Rizky 2');
      expect(repo.savedDraft!['phone'], '08123450001');
      expect(repo.receipts, isEmpty);
    },
  );

  testWidgets(
    'Name search can select a phone-free customer and replace previous text',
    (tester) async {
      final repo =
          LookupRepository()
            ..suggestions = [
              {
                'identity': 'name:rizky',
                'customer_name': 'Rizky',
                'phone': '',
                'last_visit': '2026-10-19T17:30:00Z',
                'visits': 2,
              },
            ];
      await openEditor(tester, repo);
      await typeQuery(tester, '08123', field: 'phone');
      await typeQuery(tester, 'Riz');
      expect(repo.queries.last, 'Riz');
      expect(find.text('Tanpa nomor WhatsApp'), findsOneWidget);
      await tester.ensureVisible(find.text('Rizky'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rizky'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('order-customer-phone')),
            )
            .controller!
            .text,
        '',
      );
    },
  );

  testWidgets('WhatsApp search fills the chosen name and phone', (
    tester,
  ) async {
    final repo = LookupRepository();
    await openEditor(tester, repo);
    await typeQuery(tester, '08123', field: 'phone');
    expect(repo.queries.last, '08123');
    await tester.ensureVisible(find.text('Rizky 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rizky 1'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('order-customer-name')),
          )
          .controller!
          .text,
      'Rizky 1',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('order-customer-phone')),
          )
          .controller!
          .text,
      '08123450000',
    );
  });

  testWidgets(
    'Debounce ignores brief queries and cancels query after clearing',
    (tester) async {
      final repo = LookupRepository();
      await openEditor(tester, repo);
      await typeQuery(tester, 'R');
      expect(repo.queries, isEmpty);
      await typeQuery(tester, 'Ri', wait: false);
      await tester.enterText(
        find.byKey(const ValueKey('order-customer-name')),
        'Riz',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(repo.queries, ['Riz']);
      await tester.enterText(
        find.byKey(const ValueKey('order-customer-name')),
        'Baru',
      );
      await tester.enterText(
        find.byKey(const ValueKey('order-customer-name')),
        '',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(repo.queries, ['Riz']);
      expect(find.text('Pilih pelanggan lama'), findsNothing);
    },
  );

  testWidgets('Stale search responses never replace the latest suggestions', (
    tester,
  ) async {
    final repo = LookupRepository();
    repo.pending['Lama'] = Completer<List<Json>>();
    await openEditor(tester, repo);
    await typeQuery(tester, 'Lama');
    await typeQuery(tester, 'Baru');
    expect(find.text('Rizky 1'), findsOneWidget);
    repo.pending['Lama']!.complete([
      {
        'identity': 'old',
        'customer_name': 'Hasil kedaluwarsa',
        'phone': '',
        'last_visit': '2026-10-03T00:00:00Z',
        'visits': 1,
      },
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Hasil kedaluwarsa'), findsNothing);
    expect(find.text('Rizky 1'), findsOneWidget);
  });

  testWidgets(
    'Missing migration permits manual new customer save and supports retry',
    (tester) async {
      final repo = LookupRepository()..failLookup = true;
      await openEditor(tester, repo);
      await typeQuery(tester, 'Pelanggan Baru');
      expect(
        find.textContaining('011_customer_suggestions.sql'),
        findsOneWidget,
      );
      repo.failLookup = false;
      repo.suggestions = [];
      await tester.ensureVisible(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Lanjutkan sebagai pelanggan baru'),
        findsOneWidget,
      );
      await addService(tester);
      await saveOrder(tester);
      expect(repo.savedDraft!['customer_name'], 'Pelanggan Baru');
      expect(repo.saves, 1);
    },
  );

  testWidgets('Selected customer can be adjusted manually for this note', (
    tester,
  ) async {
    final repo = LookupRepository();
    await openEditor(tester, repo);
    await typeQuery(tester, 'Riz');
    await tester.ensureVisible(find.text('Rizky 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rizky 1'));
    await tester.pumpAndSettle();
    repo.suggestions = [];
    await typeQuery(tester, 'Rizky Baru');
    await typeQuery(tester, '08129999999', field: 'phone');
    await addService(tester);
    await saveOrder(tester);
    expect(repo.savedDraft!['customer_name'], 'Rizky Baru');
    expect(repo.savedDraft!['phone'], '08129999999');
    expect(repo.saves, 1);
  });

  testWidgets(
    'Manual customer save does not wait for failed or unfinished suggestions',
    (tester) async {
      final repo = LookupRepository()..failLookup = true;
      await openEditor(tester, repo);
      await typeQuery(tester, 'Customer Manual');
      expect(
        find.textContaining('011_customer_suggestions.sql'),
        findsOneWidget,
      );
      await addService(tester);
      await saveOrder(tester);
      expect(repo.saves, 1);
      expect(repo.savedDraft!['customer_name'], 'Customer Manual');
    },
  );

  testWidgets('First suggestion stays selectable with keyboard space reserved', (
    tester,
  ) async {
    final repo = LookupRepository();
    await openEditor(tester, repo);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await typeQuery(tester, 'Riz');
    // Check the first choice is within the visible list when the keyboard is open.
    await tester.ensureVisible(find.text('Rizky 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rizky 1'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih pelanggan lama'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Existing order edit never automatically replaces historical customer fields',
    (tester) async {
      final repo = LookupRepository();
      await openEditor(tester, repo, existing: {...draft(), 'items': []});
      await typeQuery(tester, 'Nama Diperbaiki');
      expect(repo.queries, isEmpty);
      expect(find.text('Pilih pelanggan lama'), findsNothing);
    },
  );

  testWidgets(
    'Suggestions fit narrow phone with enlarged text and support active staff roles',
    (tester) async {
      for (final role in ['owner', 'admin', 'technician']) {
        final repo = LookupRepository()..accessRole = role;
        await openEditor(
          tester,
          repo,
          size: const Size(320, 740),
          textScale: 1.5,
        );
        await typeQuery(tester, 'Riz');
        expect(find.text('Rizky 1'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
    },
  );
}

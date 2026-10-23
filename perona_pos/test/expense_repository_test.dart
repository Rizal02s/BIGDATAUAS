import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:perona_pos/domain.dart';
import 'package:perona_pos/main.dart' show errorText;
import 'package:perona_pos/repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'Owner expense RPCs use inclusive calendar dates and preserve cash source',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((r) async {
          requests.add(r);
          return http.Response(
            r.url.path.endsWith('expense_report')
                ? '{"total":25000,"count":1,"history_count":2,"drawer_cash":25000,"rows":[],"categories":[]}'
                : 'null',
            200,
            headers: {'content-type': 'application/json'},
            request: r,
          );
        }),
      );
      addTearDown(client.dispose);
      final repo = Repository(client)..accessRole = 'owner';
      final report = await repo.expenses(
        Period.betweenDates(DateTime(2026, 10, 1), DateTime(2026, 10, 23)),
        1,
      );
      expect(jsonDecode(requests.first.body), {
        'p_start': '2026-10-01',
        'p_end': '2026-10-23',
        'p_page': 1,
      });
      expect(
        [report.total, report.count, report.historyCount, report.drawerCash],
        [25000, 1, 2, 25000],
      );
      await repo.recordExpense({
        'id': 'expense-a',
        'spent_on': '2026-10-03',
        'title': 'Cairan',
        'category': 'Bahan & peralatan',
        'amount': 25000,
        'method': 'Tunai',
        'from_drawer': true,
        'notes': '',
      });
      expect(jsonDecode(requests[1].body), {
        'p_id': 'expense-a',
        'p_date': '2026-10-03',
        'p_title': 'Cairan',
        'p_category': 'Bahan & peralatan',
        'p_amount': 25000,
        'p_method': 'Tunai',
        'p_from_drawer': true,
        'p_notes': '',
      });
      await repo.voidExpense('expense-a', '  Salah input  ');
      expect(jsonDecode(requests.last.body), {
        'p_id': 'expense-a',
        'p_reason': 'Salah input',
      });
    },
  );

  test(
    'All expense operations reject nonowners before network calls',
    () async {
      var reads = 0;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((r) async {
          reads++;
          return http.Response('null', 200, request: r);
        }),
      );
      addTearDown(client.dispose);
      final repo = Repository(client);
      for (final role in [
        'admin',
        'staff',
        'technician',
        'pending',
        'disabled',
      ]) {
        repo.accessRole = role;
        await expectLater(
          repo.expenses(Period.forDate(DateTime(2026, 10, 1), 'month'), 0),
          throwsStateError,
        );
        await expectLater(repo.recordExpense({}), throwsStateError);
        await expectLater(
          repo.voidExpense('a', 'Salah input'),
          throwsStateError,
        );
      }
      expect(reads, 0);
    },
  );

  test('Missing expense migration produces exact setup instruction', () {
    for (final name in [
      'expense_report',
      'business_expenses',
      'record_expense',
      'void_expense',
    ]) {
      expect(
        errorText(
          PostgrestException(code: 'PGRST202', message: 'Missing $name'),
        ),
        contains('010_business_expenses.sql'),
      );
    }
  });
}

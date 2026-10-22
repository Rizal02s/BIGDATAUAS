import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:perona_pos/domain.dart';
import 'package:perona_pos/main.dart' show errorText;
import 'package:perona_pos/repository.dart';
import 'package:perona_pos/wage_payments.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final period = Period.forDate(DateTime(2026, 10, 1), 'month');
  final ledger = WageLedger.fromJson({
    'worker_id': 'worker',
    'worker_name': 'Dina',
    'fingerprint': 'snapshot',
    'earned': 50000,
    'paid': 10000,
    'remaining': 40000,
    'excess': 0,
    'notes': [],
    'history': [],
  });

  test(
    'wage API uses note period and fingerprint while payment date stays independent',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((r) async {
          requests.add(r);
          final Object? response =
              r.url.path.endsWith('wage_overview')
                  ? []
                  : r.url.path.endsWith('wage_ledger')
                  ? {
                    'worker_id': 'worker',
                    'worker_name': 'Dina',
                    'fingerprint': 'snapshot',
                    'earned': 50000,
                    'paid': 10000,
                    'remaining': 40000,
                    'excess': 0,
                  }
                  : r.url.path.endsWith('void_wage_payout')
                  ? null
                  : {'id': 'request-id'};
          return http.Response(jsonEncode(response), 200, request: r);
        }),
      );
      addTearDown(client.dispose);
      final repo = Repository(client)..accessRole = 'owner';
      await repo.wageOverview(period);
      final report = await repo.wageLedger('worker', period);
      expect(report.remaining, 40000);
      final paidAt = jakartaToUtc(DateTime.utc(2026, 11, 2, 9, 30));
      for (var i = 0; i < 2; i++) {
        await repo.payWages(
          id: 'request-id',
          ledger: report,
          period: period,
          amount: 15000,
          method: 'Transfer',
          paidAt: paidAt,
          notes: '  Cicilan  ',
        );
      }
      await repo.voidWagePayout('request-id', '  Salah nominal  ');
      expect(requests.map((r) => r.url.path.split('/').last), [
        'wage_overview',
        'wage_ledger',
        'pay_wages',
        'pay_wages',
        'void_wage_payout',
      ]);
      expect(jsonDecode(requests[2].body), {
        'p_id': 'request-id',
        'p_worker': 'worker',
        'p_start': period.start.toIso8601String(),
        'p_end': period.end.toIso8601String(),
        'p_fingerprint': 'snapshot',
        'p_amount': 15000,
        'p_method': 'Transfer',
        'p_paid_at': '2026-11-02T02:30:00.000Z',
        'p_notes': 'Cicilan',
      });
      expect(requests[2].body, requests[3].body);
      expect(jsonDecode(requests.last.body), {
        'p_id': 'request-id',
        'p_reason': 'Salah nominal',
      });
    },
  );

  test(
    'model preserves per-note balances and history including overpaid corrections',
    () {
      final report = WageLedger.fromJson({
        'worker_id': 'w',
        'worker_name': 'Dina',
        'fingerprint': 'x',
        'earned': 10000,
        'paid': 25000,
        'remaining': 5000,
        'excess': 20000,
        'notes': [
          {'order_id': 'deleted', 'deleted': true, 'excess': 20000},
        ],
        'history': [
          {'id': 'p', 'voided_at': '2026-10-01', 'amount': 50000},
        ],
      });
      expect(report.remaining, 5000);
      expect(report.excess, 20000);
      expect(report.notes.single['deleted'], isTrue);
      expect(report.history.single['voided_at'], isNotNull);
    },
  );

  test('admin cannot read wages and only owner can pay or correct', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(
        (_) async => throw StateError('Unexpected API request'),
      ),
    );
    addTearDown(client.dispose);
    final repo = Repository(client);
    for (final role in ['admin', 'pending', 'disabled']) {
      repo.accessRole = role;
      await expectLater(repo.wageOverview(period), throwsStateError);
      await expectLater(repo.wageLedger('w', period), throwsStateError);
    }
    for (final role in ['admin', 'staff', 'technician', 'pending']) {
      repo.accessRole = role;
      await expectLater(
        repo.payWages(
          id: 'p',
          ledger: ledger,
          period: period,
          amount: 1000,
          method: 'Tunai',
          notes: '',
        ),
        throwsStateError,
      );
      await expectLater(
        repo.voidWagePayout('p', 'Salah input'),
        throwsStateError,
      );
    }
  });

  test('missing wage RPC explains migration 008', () {
    for (final name in [
      'wage_overview',
      'wage_ledger',
      'pay_wages',
      'void_wage_payout',
    ]) {
      expect(
        errorText(
          PostgrestException(
            code: 'PGRST202',
            message: 'Could not find public.$name',
          ),
        ),
        contains('008_wage_payments.sql'),
      );
    }
  });
}

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
    'Operational RPC uses WIB period as UTC and redacted report fields with pagination',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((r) async {
          requests.add(r);
          return http.Response(
            jsonEncode({
              'count': 1001,
              'gross': 240000,
              'revenue': 230000,
              'discount': 10000,
              'pending': 2,
              'ready': 1,
              'picked_up': 3,
              'overdue': 1,
              'due_today': 1,
              'outstanding_period': 40000,
              'outstanding_all': 90000,
              'received': 120000,
              'cash': 80000,
              'qris': 20000,
              'transfer': 20000,
              'receipt_count': 35,
              'payments': [
                {'id': 'p', 'amount': 20000},
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: r,
          );
        }),
      );
      addTearDown(client.dispose);
      final repo = Repository(client)..accessRole = 'admin';
      final result = await repo.operationalReport(
        Period.forDate(DateTime(2026, 10, 3), 'day'),
        page: 1,
      );
      expect(requests.single.url.path, endsWith('/rpc/operational_report'));
      expect(jsonDecode(requests.single.body), {
        'p_start': '2026-10-02T17:00:00.000Z',
        'p_end': '2026-10-03T17:00:00.000Z',
        'p_page': 1,
      });
      expect(
        [
          result.count,
          result.pending,
          result.ready,
          result.pickedUp,
          result.overdue,
          result.dueToday,
        ],
        [1001, 2, 1, 3, 1, 1],
      );
      expect(
        [
          result.gross,
          result.revenue,
          result.discount,
          result.received,
          result.cash,
          result.qris,
          result.transfer,
        ],
        [240000, 230000, 10000, 120000, 80000, 20000, 20000],
      );
      expect(
        [
          result.outstandingPeriod,
          result.outstandingAll,
          result.receiptCount,
          result.payments.length,
        ],
        [40000, 90000, 35, 1],
      );
      await expectLater(
        repo.report(Period.forDate(DateTime(2026, 10, 3), 'day')),
        throwsStateError,
      );
      expect(requests, hasLength(1));
    },
  );
  test(
    'Operational reports reject inactive and technician roles before sending a request',
    () async {
      var calls = 0;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((r) async {
          calls++;
          return http.Response('{}', 200, request: r);
        }),
      );
      addTearDown(client.dispose);
      final repo = Repository(client);
      for (final role in ['pending', 'disabled', 'staff', 'technician']) {
        repo.accessRole = role;
        await expectLater(
          repo.operationalReport(Period.forDate(DateTime(2026, 10), 'month')),
          throwsStateError,
        );
      }
      expect(calls, 0);
      expect(
        errorText(
          const PostgrestException(
            code: 'PGRST202',
            message: 'Missing operational_report',
          ),
        ),
        contains('012_admin_operational_report.sql'),
      );
    },
  );
}

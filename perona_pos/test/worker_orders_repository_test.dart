import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:perona_pos/domain.dart';
import 'package:perona_pos/report_data.dart';
import 'package:perona_pos/repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const workerId = 'e2869677-6d37-4e5f-b146-c06ae550a83c';

void main() {
  final period = Period.forDate(DateTime(2026, 10, 1), 'month');

  Repository repository(List<http.Request> requests, List<Json> rows) {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request);
        final filter = request.url.queryParameters['items'];
        if (filter != null) {
          try {
            final value = jsonDecode(filter.substring(3));
            if (filter.startsWith('cs.') &&
                value is List &&
                value.length == 1 &&
                value.single is Map &&
                value.single['worker_id'] == workerId) {
              return http.Response(jsonEncode(rows), 200, request: request);
            }
          } on FormatException {
            // Reproduce the server rejecting a PostgreSQL array as JSONB.
          }
          return http.Response(
            jsonEncode({
              'code': '22P02',
              'message': 'invalid input syntax for type json',
            }),
            400,
            request: request,
          );
        }
        return http.Response(jsonEncode(rows), 200, request: request);
      }),
    );
    addTearDown(client.dispose);
    return Repository(client)..accessRole = 'owner';
  }

  test(
    'worker wage query loads customers and groups their wages per receipt',
    () async {
      final requests = <http.Request>[];
      final repo = repository(requests, [
        {
          'id': 'order-a',
          'number': 1,
          'customer_name': 'Ayu',
          'created_at': '2026-10-03T03:15:00Z',
          'items': [
            {
              'name': 'Deep Clean',
              'quantity': 2,
              'labor_fee': 10000,
              'worker_id': workerId,
            },
            {
              'name': 'Fast Clean',
              'quantity': 1,
              'labor_fee': 5000,
              'worker_id': workerId,
            },
            {
              'name': 'Repaint',
              'quantity': 1,
              'labor_fee': 30000,
              'worker_id': 'other-worker',
            },
          ],
        },
        {
          'id': 'order-b',
          'number': 2,
          'customer_name': 'Nadia Putri',
          'created_at': '2026-10-04T03:15:00Z',
          'items': [
            {
              'name': 'Deep Clean',
              'quantity': 1,
              'labor_fee': 10000,
              'worker_id': workerId,
            },
          ],
        },
      ]);

      final orders = await repo.allOrders(period, workerId: workerId);
      final report = WorkerReport(reportOrders(orders, period), workerId);
      expect(report.notes.map((note) => note.order['customer_name']), [
        'Ayu',
        'Nadia Putri',
      ]);
      expect(report.notes.map((note) => note.wage), [25000, 10000]);
      expect(report.total, 35000);
      final params = requests.single.url.queryParametersAll;
      expect(params['created_at'], [
        'gte.${period.start.toIso8601String()}',
        'lt.${period.end.toIso8601String()}',
      ]);
      expect(params['deleted_at'], ['is.null']);
      expect(params['limit'], ['30']);
    },
  );

  test('worker calendar query uses a valid JSONB filter too', () async {
    final requests = <http.Request>[];
    final repo = repository(requests, [
      {'id': 'order-a', 'created_at': '2026-10-03T03:15:00Z'},
      {'id': 'order-b', 'created_at': '2026-10-03T04:15:00Z'},
    ]);
    expect(await repo.orderDayCounts(DateTime(2026, 10), workerId: workerId), {
      3: 2,
    });
    expect(requests, hasLength(1));
  });

  test('team wage query keeps all workers without a worker filter', () async {
    final requests = <http.Request>[];
    final repo = repository(requests, []);
    expect(await repo.allOrders(period), isEmpty);
    expect(requests.single.url.queryParameters.containsKey('items'), isFalse);
  });
}

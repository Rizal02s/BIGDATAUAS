import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:perona_pos/main.dart' show errorText;
import 'package:perona_pos/order_deadlines.dart';
import 'package:perona_pos/repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'Deadline is inclusive through midnight WIB, independent of device timezone',
    () {
      final order = <String, dynamic>{'due_date': '2026-10-23'};
      expect(
        orderDeadline(order, now: DateTime.parse('2026-10-23T16:59:59Z')),
        DeadlineFilter.today,
      );
      expect(
        orderDeadline(order, now: DateTime.parse('2026-10-23T17:00:00Z')),
        DeadlineFilter.overdue,
      );
      expect(
        orderDeadline(order, now: DateTime.parse('2026-10-22T16:59:59Z')),
        DeadlineFilter.upcoming,
      );
      expect(
        orderDeadline({}, now: DateTime.now()),
        DeadlineFilter.unscheduled,
      );
    },
  );

  test(
    'Ready and picked up do not count as overdue work; assigned items determine personal queue',
    () {
      final order = <String, dynamic>{
        'items': [
          {'worker_id': 'a', 'status': 'Selesai'},
          {'worker_id': 'a', 'status': 'Diambil'},
          {'worker_id': 'b', 'status': 'Dikerjakan'},
        ],
      };
      expect(orderNeedsWork(order), true);
      expect(orderNeedsWork(order, workerId: 'a'), false);
      expect(orderNeedsWork(order, workerId: 'b'), true);
      expect(orderNeedsWork(order, workerId: 'c'), false);
      expect(orderNeedsWork({...order, 'deleted_at': '2026-10-01'}), false);
    },
  );

  test(
    'Estimate RPC preserves calendar date, clearing null, and queue pagination parameters',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((r) async {
          requests.add(r);
          return http.Response(
            r.url.path.endsWith('work_queue') ? '[]' : 'null',
            200,
            headers: {'content-type': 'application/json'},
            request: r,
          );
        }),
      );
      addTearDown(client.dispose);
      final repo = Repository(client);
      final order = <String, dynamic>{
        'id': 'a',
        'items': [],
        'due_date': '2026-10-24',
      };
      await repo.saveOrder(order);
      await repo.saveOrder({...order, 'due_date': null});
      await repo.workQueue(DeadlineFilter.overdue, 2, workerId: 'worker');
      expect(requests[0].url.path, endsWith('save_order_with_estimate'));
      expect(jsonDecode(requests[0].body)['p_due_date'], '2026-10-24');
      expect(jsonDecode(requests[1].body)['p_due_date'], null);
      expect(jsonDecode(requests[2].body), {
        'p_filter': 'overdue',
        'p_page': 2,
        'p_worker': 'worker',
      });
    },
  );

  test('Missing migration gives exact setup instruction', () {
    for (final rpc in ['save_order_with_estimate', 'work_queue']) {
      expect(
        errorText(
          PostgrestException(code: 'PGRST202', message: 'Missing public.$rpc'),
        ),
        contains('009_order_deadlines.sql'),
      );
    }
  });
}

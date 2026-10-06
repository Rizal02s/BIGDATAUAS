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
    'Order and initial payment RPCs send selected UTC date; later payment uses server now',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            'null',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final repo = Repository(client);
      final selectedAt = jakartaToUtc(DateTime.utc(2026, 10, 3, 0, 5));
      await repo.saveOrder({
        'id': 'order-a',
        'version': 0,
        'customer_name': 'Customer tanggal 3',
        'phone': '',
        'notes': '',
        'discount': 0,
        'items': [],
        'created_at': selectedAt.toIso8601String(),
      });
      await repo.pay(
        'payment-a',
        'order-a',
        30000,
        'Tunai',
        paidAt: selectedAt,
      );
      await repo.pay('payment-b', 'order-a', 10000, 'QRIS');
      expect(requests.map((r) => r.url.path.split('/').last), [
        'save_order_with_date',
        'add_payment_with_date',
        'add_payment',
      ]);
      expect(
        jsonDecode(requests[0].body)['p_order_at'],
        '2026-10-02T17:05:00.000Z',
      );
      expect(
        jsonDecode(requests[1].body)['p_paid_at'],
        '2026-10-02T17:05:00.000Z',
      );
      expect(
        (jsonDecode(requests[2].body) as Map).containsKey('p_paid_at'),
        false,
      );
    },
  );

  test('Missing dated RPC gives an actionable migration message', () {
    for (final rpc in ['save_order_with_date', 'add_payment_with_date']) {
      expect(
        errorText(
          PostgrestException(
            code: 'PGRST202',
            message: 'Could not find the function public.$rpc',
          ),
        ),
        contains('004_manual_order_dates.sql'),
      );
    }
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:perona_pos/cash_data.dart';
import 'package:perona_pos/main.dart' show errorText;
import 'package:perona_pos/repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'cash requests use day RPC and send source fingerprint previous ID and stable request ID',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode(
              request.url.path.endsWith('cash_day')
                  ? {
                    'date': '2026-10-23',
                    'fingerprint': 'v1',
                    'cash': 30000,
                    'closing': {'id': 'previous'},
                    'payments': [],
                  }
                  : {'id': 'request-id'},
            ),
            200,
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final repo = Repository(client)..accessRole = 'admin';
      final day = await repo.cashDay(DateTime.utc(2026, 10, 23, 23, 59));
      for (var attempt = 0; attempt < 2; attempt++) {
        await repo.closeCash(
          id: 'request-id',
          day: day,
          opening: 100000,
          cashOut: 10000,
          counted: 120000,
          notes: '  Hitung ulang  ',
        );
      }
      expect(requests.map((r) => r.url.path.split('/').last), [
        'cash_day',
        'save_cash_closing',
        'save_cash_closing',
      ]);
      expect(jsonDecode(requests.first.body), {'p_date': '2026-10-23'});
      expect(jsonDecode(requests[1].body), {
        'p_id': 'request-id',
        'p_date': '2026-10-23',
        'p_previous_id': 'previous',
        'p_fingerprint': 'v1',
        'p_opening': 100000,
        'p_cash_out': 10000,
        'p_counted': 120000,
        'p_notes': 'Hitung ulang',
      });
      expect(requests[1].body, requests[2].body);
    },
  );

  test(
    'cash access is blocked for technician pending and disabled before API calls',
    () async {
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
      final day = CashDay.fromJson({'date': '2026-10-23', 'fingerprint': 'x'});
      for (final role in ['staff', 'technician', 'pending', 'disabled']) {
        repo.accessRole = role;
        await expectLater(
          repo.cashDay(DateTime(2026, 10, 23)),
          throwsStateError,
        );
        await expectLater(
          repo.closeCash(
            id: 'x',
            day: day,
            opening: 0,
            cashOut: 0,
            counted: 0,
            notes: '',
          ),
          throwsStateError,
        );
      }
    },
  );

  test('missing cash RPC names explain the required migration', () {
    for (final name in ['cash_day', 'save_cash_closing']) {
      expect(
        errorText(
          PostgrestException(
            code: 'PGRST202',
            message: 'Could not find public.$name',
          ),
        ),
        contains('007_daily_cash.sql'),
      );
    }
  });
}

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:perona_pos/domain.dart';
import 'package:perona_pos/employee_accounts.dart';
import 'package:perona_pos/repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountRepository extends Repository {
  AccountRepository(super.db);
  @override
  String get userId => 'owner-a';
}

void main() {
  test(
    'Owner invokes server account deletion; directory uses redacted RPC',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'public-test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((r) async {
          requests.add(r);
          return http.Response(
            r.url.path.endsWith('staff_directory')
                ? '[{"id":"a","name":"Pegawai","role":"technician"}]'
                : '{"deleted":true,"id":"a"}',
            200,
            headers: {'content-type': 'application/json'},
            request: r,
          );
        }),
      );
      addTearDown(client.dispose);
      final repo = AccountRepository(client)..accessRole = 'owner';
      await repo.deleteEmployee({
        'id': 'a',
        'role': 'technician',
      }, '  Pegawai keluar  ');
      expect(requests.single.url.path, '/functions/v1/delete-employee-account');
      expect(jsonDecode(requests.single.body), {
        'id': 'a',
        'expected_role': 'technician',
        'reason': 'Pegawai keluar',
      });
      expect(requests.single.body.contains('service_role'), false);
      expect((await repo.staff()).single['name'], 'Pegawai');
      expect(requests.last.url.path, '/rest/v1/rpc/staff_directory');
    },
  );
  test(
    'Nonowner own-account and other-owner deletion rejected before network request',
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
      final repo = AccountRepository(client);
      for (final role in ['admin', 'technician', 'staff', 'pending']) {
        repo.accessRole = role;
        await expectLater(
          repo.deleteEmployee({
            'id': 'a',
            'role': 'technician',
          }, 'Alasan hapus'),
          throwsA(isA<EmployeeDeletionFailure>()),
        );
      }
      repo.accessRole = 'owner';
      for (final person in <Json>[
        {'id': 'owner-a', 'role': 'owner'},
        {'id': 'owner-b', 'role': 'owner'},
        {'id': 'a', 'role': 'technician'},
      ]) {
        await expectLater(
          repo.deleteEmployee(person, 'x'),
          throwsA(isA<EmployeeDeletionFailure>()),
        );
      }
      expect(calls, 0);
    },
  );
  test(
    'Pending server deletion and missing Edge deployment stay actionable',
    () async {
      var status = 503;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient(
          (r) async => http.Response(
            '{"pending":true,"error":"Penghapusan login belum selesai"}',
            status,
            headers: {'content-type': 'application/json'},
            request: r,
          ),
        ),
      );
      addTearDown(client.dispose);
      final repo = AccountRepository(client)..accessRole = 'owner';
      await expectLater(
        repo.deleteEmployee({
          'id': 'a',
          'role': 'technician',
        }, 'Pegawai keluar'),
        throwsA(
          isA<EmployeeDeletionFailure>().having(
            (e) => e.pending,
            'pending',
            true,
          ),
        ),
      );
      status = 404;
      await expectLater(
        repo.deleteEmployee({
          'id': 'a',
          'role': 'technician',
        }, 'Pegawai keluar'),
        throwsA(
          isA<EmployeeDeletionFailure>().having(
            (e) => e.message,
            'message',
            contains('Deploy fungsi'),
          ),
        ),
      );
    },
  );
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:perona_pos/domain.dart';
import 'package:perona_pos/repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _legacyError =
    'Masih ada pembayaran. Penghapusan hanya untuk koreksi order; koreksi pembayaran lebih dahulu.';
const _selected = <String, dynamic>{'id': 'order-a', 'version': 4};

class DeletionServer {
  final requests = <http.Request>[];
  final corrected = <String>[];
  List<Json> payments = [
    {'id': 'payment-a', 'amount': 10000, 'voided_at': null},
    {'id': 'payment-b', 'amount': 5000, 'voided_at': null},
    {'id': 'payment-old', 'amount': 5000, 'voided_at': '2026-10-01T00:00:00Z'},
  ];
  bool legacy = true, removed = false, changedAfterCorrection = false;
  String? deleteError, failCorrection;
  int version = 4;

  http.Response response(
    http.Request request,
    Object? data, {
    int status = 200,
  }) => http.Response(
    jsonEncode(data),
    status,
    headers: {'content-type': 'application/json'},
    request: request,
  );

  http.Response error(http.Request request, String message) =>
      response(request, {'code': 'P0001', 'message': message}, status: 400);

  Future<http.Response> handle(http.Request request) async {
    requests.add(request);
    if (request.method == 'GET') {
      return response(request, {
        'id': 'order-a',
        'version': version,
        'customer_name': 'Order duplikat',
        'payments': payments,
      });
    }
    final params = jsonDecode(request.body) as Map;
    if (request.url.path.endsWith('/void_payment')) {
      final id = params['p_id'] as String;
      if (id == failCorrection) throw http.ClientException('Koneksi terputus');
      corrected.add(id);
      payments.firstWhere((p) => p['id'] == id)['voided_at'] =
          '2026-10-22T00:00:00Z';
      version++;
      if (changedAfterCorrection && corrected.length == 1) version++;
      return response(request, null);
    }
    if (params['p_version'] != version) {
      return error(request, 'Order berubah. Muat ulang terlebih dahulu.');
    }
    if (deleteError != null) return error(request, deleteError!);
    if (legacy && payments.any((p) => p['voided_at'] == null)) {
      return error(request, _legacyError);
    }
    removed = true;
    return response(request, null);
  }

  Repository repository() {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(handle),
    );
    addTearDown(client.dispose);
    return Repository(client)..accessRole = 'owner';
  }

  List<String> get calls =>
      requests.map((r) => r.url.path.split('/').last).toList();
}

void main() {
  test('new backend deletes paid order in one RPC', () async {
    final server = DeletionServer()..legacy = false;
    await server.repository().delete(_selected, 'Dihapus oleh owner.');
    expect(server.calls, ['delete_order']);
    expect(server.removed, isTrue);
    expect(server.corrected, isEmpty);
  });

  test(
    'old backend automatically corrects active payments and deletes with current version',
    () async {
      final server = DeletionServer();
      await server.repository().delete(_selected, 'Dihapus oleh owner.');
      expect(server.calls, [
        'delete_order',
        'orders',
        'void_payment',
        'void_payment',
        'orders',
        'delete_order',
      ]);
      expect(server.corrected, ['payment-a', 'payment-b']);
      expect(server.removed, isTrue);
      expect(jsonDecode(server.requests.last.body), {
        'p_id': 'order-a',
        'p_version': 6,
        'p_reason': 'Dihapus oleh owner.',
      });
      expect(
        jsonDecode(server.requests[2].body)['p_reason'],
        'Order dihapus: Dihapus oleh owner.',
      );
    },
  );

  test(
    'unpaid order and previously corrected payments delete without extra calls',
    () async {
      final server =
          DeletionServer()
            ..payments = [
              {
                'id': 'old-payment',
                'amount': 10000,
                'voided_at': '2026-10-01T00:00:00Z',
              },
            ];
      await server.repository().delete(_selected, 'Dihapus oleh owner.');
      expect(server.calls, ['delete_order']);
      expect(server.removed, isTrue);
    },
  );

  test(
    'owner restrictions do not trigger automatic payment correction',
    () async {
      final server =
          DeletionServer()..deleteError = 'Hanya owner yang diizinkan.';
      await expectLater(
        server.repository().delete(_selected, 'Dihapus oleh owner.'),
        throwsA(isA<PostgrestException>()),
      );
      expect(server.calls, ['delete_order']);
      expect(server.corrected, isEmpty);
    },
  );

  test('stale selection never changes payments', () async {
    final server = DeletionServer()..version = 5;
    await expectLater(
      server.repository().delete(_selected, 'Dihapus oleh owner.'),
      throwsA(isA<PostgrestException>()),
    );
    expect(server.corrected, isEmpty);
    expect(server.removed, isFalse);
  });

  test(
    'concurrent changes during automatic correction prevent deletion',
    () async {
      final server = DeletionServer()..changedAfterCorrection = true;
      await expectLater(
        server.repository().delete(_selected, 'Dihapus oleh owner.'),
        throwsStateError,
      );
      expect(server.calls.last, 'orders');
      expect(server.removed, isFalse);
    },
  );

  test(
    'retry resumes after interruption without repeating successful corrections',
    () async {
      final server = DeletionServer()..failCorrection = 'payment-b';
      final repo = server.repository();
      await expectLater(
        repo.delete(_selected, 'Dihapus oleh owner.'),
        throwsA(isA<http.ClientException>()),
      );
      expect(server.removed, isFalse);
      expect(server.corrected, ['payment-a']);
      server.failCorrection = null;
      await repo.delete({
        'id': 'order-a',
        'version': server.version,
      }, 'Dihapus oleh owner.');
      expect(server.corrected, ['payment-a', 'payment-b']);
      expect(server.removed, isTrue);
    },
  );
}

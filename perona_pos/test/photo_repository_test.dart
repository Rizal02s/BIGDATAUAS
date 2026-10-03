import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:perona_pos/repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PhotoRepository extends Repository {
  PhotoRepository(super.db);
  @override
  String get userId => 'staff-a';
}

void main() {
  test(
    'retries an existing Storage object and never duplicates photo metadata',
    () async {
      var linked = false;
      var uploads = 0, inserts = 0;
      final httpClient = MockClient((request) async {
        if (request.url.path.contains('/storage/v1/object/')) {
          uploads++;
          return http.Response(
            jsonEncode({
              'message': 'Already exists',
              'error': 'Duplicate',
              'statusCode': '409',
            }),
            409,
            request: request,
          );
        }
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode(
              linked
                  ? [
                    {'id': 'photo-a'},
                  ]
                  : [],
            ),
            200,
            request: request,
          );
        }
        inserts++;
        linked = true;
        // Simulate a lost acknowledgement after metadata was committed.
        throw http.ClientException('Response lost');
      });
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: httpClient,
      );
      addTearDown(client.dispose);
      final repo = PhotoRepository(client);
      await repo.uploadPhoto(
        'order-a',
        Uint8List(1),
        'png',
        photoId: 'photo-a',
      );
      await repo.uploadPhoto(
        'order-a',
        Uint8List(1),
        'png',
        photoId: 'photo-a',
      );
      expect(uploads, 1);
      expect(inserts, 1);
    },
  );

  test(
    'rejects oversized or unsupported photos before a network request',
    () async {
      var requests = 0;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((_) async {
          requests++;
          return http.Response('{}', 200);
        }),
      );
      addTearDown(client.dispose);
      final repo = PhotoRepository(client);
      await expectLater(
        repo.uploadPhoto('order-a', Uint8List(2 * 1024 * 1024 + 1), 'png'),
        throwsException,
      );
      await expectLater(
        repo.uploadPhoto('order-a', Uint8List(1), 'heic'),
        throwsException,
      );
      expect(requests, 0);
    },
  );
}

import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'domain.dart';

class Repository {
  final SupabaseClient db;
  Repository(this.db);
  String accessRole = 'pending';
  bool get isAdmin => accessRole == 'admin';
  bool get canViewWages =>
      ['owner', 'staff', 'technician'].contains(accessRole);
  String get userId => db.auth.currentUser!.id;
  Future<Json> profile() async {
    final result = await db.from('profiles').select().eq('id', userId).single();
    accessRole = result['role'] as String;
    return result;
  }

  Future<List<Json>> _all(String table, String order) async {
    final result = <Json>[];
    for (var offset = 0; ; offset += 500) {
      final rows = await db
          .from(table)
          .select()
          .order(order)
          .range(offset, offset + 499);
      result.addAll(rows);
      if (rows.length < 500) break;
    }
    return result;
  }

  Future<List<Json>> services() async =>
      isAdmin
          ? (await db.rpc('service_catalog') as List)
              .map((row) => Json.from(row as Map))
              .toList()
          : await _all('services', 'name');
  Future<List<Json>> staff() => _all('profiles', 'name');
  Future<List<Json>> orders(Period period, int page, {String? workerId}) async {
    if (isAdmin) {
      final rows = await db.rpc(
        'order_list',
        params: {
          'p_start': period.start.toIso8601String(),
          'p_end': period.end.toIso8601String(),
          'p_page': page,
          'p_worker': workerId,
        },
      );
      return (rows as List).map((row) => Json.from(row as Map)).toList();
    }
    var query = db
        .from('orders')
        .select('*, payments(*), order_photos(id)')
        .isFilter('deleted_at', null)
        .gte('created_at', period.start.toIso8601String())
        .lt('created_at', period.end.toIso8601String());
    if (workerId != null) {
      query = query.contains('items', [
        {'worker_id': workerId},
      ]);
    }
    return await query
        .order('created_at', ascending: false)
        .order('id')
        .range(page * 30, page * 30 + 29);
  }

  Future<Json> report(Period period) async {
    if (!canViewWages) {
      throw StateError('Akun ini tidak memiliki akses rekap ongkos.');
    }
    final result = await db.rpc(
      'period_report',
      params: {
        'p_start': period.start.toIso8601String(),
        'p_end': period.end.toIso8601String(),
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<List<Json>> allOrders(Period period, {String? workerId}) async {
    final byId = <String, Json>{};
    for (var page = 0; ; page++) {
      final rows = await orders(period, page, workerId: workerId);
      var added = 0;
      for (final row in rows) {
        final id = row['id'] as String;
        if (!byId.containsKey(id)) added++;
        byId[id] = row;
      }
      if (rows.length < 30) break;
      if (added == 0) {
        throw StateError(
          'Halaman data berulang. Muat ulang sebelum mengunduh.',
        );
      }
    }
    return byId.values.toList();
  }

  Future<Map<int, int>> orderDayCounts(
    DateTime month, {
    String? workerId,
  }) async {
    final period = Period.forDate(month, 'month');
    if (isAdmin) {
      final counts = await db.rpc(
        'order_day_counts',
        params: {
          'p_start': period.start.toIso8601String(),
          'p_end': period.end.toIso8601String(),
          'p_worker': workerId,
        },
      );
      return (counts as Map).map(
        (day, count) => MapEntry(int.parse(day as String), money(count)),
      );
    }
    final counts = <int, int>{};
    // Read all pages of timestamps; a busy month's counts must not depend on
    // the 30 orders displayed on an individual day page.
    for (var offset = 0; ; offset += 500) {
      var query = db
          .from('orders')
          .select('id, created_at')
          .isFilter('deleted_at', null)
          .gte('created_at', period.start.toIso8601String())
          .lt('created_at', period.end.toIso8601String());
      if (workerId != null) {
        query = query.contains('items', [
          {'worker_id': workerId},
        ]);
      }
      final rows = await query
          .order('created_at')
          .order('id')
          .range(offset, offset + 499);
      for (final row in rows) {
        final day = jakarta(DateTime.parse(row['created_at'] as String)).day;
        counts.update(day, (count) => count + 1, ifAbsent: () => 1);
      }
      if (rows.length < 500) break;
    }
    return counts;
  }

  Future<Json> order(String id) async =>
      isAdmin
          ? Json.from(await db.rpc('order_detail', params: {'p_id': id}) as Map)
          : await db
              .from('orders')
              .select('*, payments(*), order_photos(*)')
              .eq('id', id)
              .single();
  Future<void> saveOrder(Json order) async {
    await db.rpc(
      'save_order_with_date',
      params: {
        'p_id': order['id'],
        'p_version': order['version'] ?? 0,
        'p_customer': order['customer_name'],
        'p_phone': order['phone'],
        'p_notes': order['notes'],
        'p_discount': order['discount'],
        'p_items': order['items'],
        'p_order_at': order['created_at'],
      },
    );
  }

  Future<void> pay(
    String paymentId,
    String orderId,
    int amount,
    String method, {
    DateTime? paidAt,
  }) async {
    await db.rpc(
      paidAt == null ? 'add_payment' : 'add_payment_with_date',
      params: {
        'p_id': paymentId,
        'p_order': orderId,
        'p_amount': amount,
        'p_method': method,
        if (paidAt != null) 'p_paid_at': paidAt.toUtc().toIso8601String(),
      },
    );
  }

  Future<void> delete(Json order, String reason) async {
    await db.rpc(
      'delete_order',
      params: {
        'p_id': order['id'],
        'p_version': order['version'],
        'p_reason': reason,
      },
    );
  }

  Future<void> voidPayment(String id, String reason) async {
    await db.rpc('void_payment', params: {'p_id': id, 'p_reason': reason});
  }

  Future<void> saveService(Json service) async {
    await db.rpc(
      'save_service',
      params: {
        'p_id': service['id'],
        'p_name': service['name'],
        'p_category': service['category'],
        'p_price': service['price'],
        'p_labor': service['labor_fee'],
        'p_active': service['active'],
      },
    );
  }

  Future<void> setRole(String id, String role) async {
    await db.rpc('set_staff_role', params: {'p_id': id, 'p_role': role});
  }

  Future<void> uploadPhoto(
    String orderId,
    Uint8List bytes,
    String extension, {
    String? photoId,
  }) async {
    if (bytes.length > 2 * 1024 * 1024) throw Exception('Foto maksimal 2 MB.');
    final ext = extension.toLowerCase();
    final mime =
        {
          'jpg': 'image/jpeg',
          'jpeg': 'image/jpeg',
          'png': 'image/png',
          'webp': 'image/webp',
        }[ext];
    if (mime == null) throw Exception('Gunakan foto JPG, PNG, atau WebP.');
    final id = photoId ?? const Uuid().v4();
    final path = '$orderId/$userId/$id.$ext';
    Future<bool> linked() async =>
        await db
            .from('order_photos')
            .select('id')
            .eq('id', id)
            .eq('order_id', orderId)
            .eq('path', path)
            .maybeSingle() !=
        null;
    if (photoId != null && await linked()) return;
    try {
      await db.storage
          .from('order-photos')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: mime, upsert: false),
          );
    } on StorageException catch (error) {
      // A retry may find the same immutable draft photo already uploaded.
      if (error.statusCode != '409' && error.error != 'Duplicate') rethrow;
    }
    try {
      await db.from('order_photos').insert({
        'id': id,
        'order_id': orderId,
        'path': path,
        'created_by': userId,
      });
    } catch (_) {
      // A lost response after INSERT must not cause another photo on retry.
      try {
        if (await linked()) return;
      } catch (_) {}
      // Cleanup best effort; kegagalan cleanup tidak menyembunyikan error asli.
      try {
        await db.storage.from('order-photos').remove([path]);
      } catch (_) {}
      rethrow;
    }
  }

  Future<String> photoUrl(String path) =>
      db.storage.from('order-photos').createSignedUrl(path, 600);
}

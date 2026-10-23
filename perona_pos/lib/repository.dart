import 'dart:convert';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'domain.dart';
import 'cash_data.dart';
import 'wage_payments.dart';
import 'order_deadlines.dart';
import 'expense_data.dart';
import 'operational_report.dart';
import 'employee_accounts.dart';
import 'attendance_data.dart';

class Repository {
  final SupabaseClient db;
  Repository(this.db);
  String accessRole = 'pending';
  bool get isAdmin => accessRole == 'admin';
  bool get canManageCash => ['owner', 'admin'].contains(accessRole);
  bool get canViewWages =>
      ['owner', 'staff', 'technician'].contains(accessRole);
  String get userId => db.auth.currentUser!.id;

  Future<AttendanceToday> attendanceToday() async => AttendanceToday.fromJson(
    Json.from(await db.rpc('attendance_today') as Map),
  );

  Future<AttendanceEntry> recordAttendance(
    String requestId,
    String action,
    String notes,
  ) async => AttendanceEntry(
    Json.from(
      await db.rpc(
            'record_attendance',
            params: {
              'p_request_id': requestId,
              'p_action': action,
              'p_notes': notes.trim(),
            },
          )
          as Map,
    ),
  );

  Future<AttendanceReport> attendanceReport(
    Period period, {
    String? employee,
    int page = 0,
  }) async => AttendanceReport.fromJson(
    Json.from(
      await db.rpc(
            'attendance_report',
            params: {
              'p_start': attendanceDate(jakarta(period.start)),
              'p_end': attendanceDate(
                jakarta(period.end.subtract(const Duration(microseconds: 1))),
              ),
              'p_employee': employee,
              'p_page': page,
            },
          )
          as Map,
    ),
  );

  Future<void> correctAttendance(Json values) async {
    if (accessRole != 'owner') {
      throw StateError('Koreksi absensi hanya untuk owner.');
    }
    await db.rpc('correct_attendance', params: values);
  }

  Future<List<Json>> attendanceHistory(String id) async {
    if (accessRole != 'owner') {
      throw StateError('Riwayat perubahan hanya untuk owner.');
    }
    final rows = await db.rpc('attendance_history', params: {'p_id': id});
    return (rows as List).map((r) => Json.from(r as Map)).toList();
  }

  Future<OperationalReport> operationalReport(
    Period period, {
    int page = 0,
  }) async {
    if (!['owner', 'admin'].contains(accessRole)) {
      throw StateError('Laporan operasional hanya untuk owner dan admin.');
    }
    return OperationalReport.fromJson(
      Json.from(
        await db.rpc(
              'operational_report',
              params: {
                'p_start': period.start.toIso8601String(),
                'p_end': period.end.toIso8601String(),
                'p_page': page,
              },
            )
            as Map,
      ),
    );
  }

  Future<List<Json>> customerSuggestions(String query) async {
    final term = query.trim();
    if (term.length < 2) return [];
    final result = await db.rpc(
      'customer_suggestions',
      params: {'p_query': term},
    );
    return (result as List)
        .take(5)
        .map((row) => Json.from(row as Map))
        .toList();
  }

  void _requireExpenseOwner() {
    if (accessRole != 'owner') {
      throw StateError('Pengeluaran usaha hanya untuk owner.');
    }
  }

  Future<ExpenseReport> expenses(Period period, int page) async {
    _requireExpenseOwner();
    return ExpenseReport.fromJson(
      Json.from(
        await db.rpc(
              'expense_report',
              params: {
                'p_start': cashDate(jakarta(period.start)),
                'p_end': cashDate(
                  jakarta(period.end.subtract(const Duration(microseconds: 1))),
                ),
                'p_page': page,
              },
            )
            as Map,
      ),
    );
  }

  Future<void> recordExpense(Json expense) async {
    _requireExpenseOwner();
    await db.rpc(
      'record_expense',
      params: {
        'p_id': expense['id'],
        'p_date': expense['spent_on'],
        'p_title': expense['title'],
        'p_category': expense['category'],
        'p_amount': expense['amount'],
        'p_method': expense['method'],
        'p_from_drawer': expense['from_drawer'],
        'p_notes': expense['notes'],
      },
    );
  }

  Future<void> voidExpense(String id, String reason) async {
    _requireExpenseOwner();
    await db.rpc(
      'void_expense',
      params: {'p_id': id, 'p_reason': reason.trim()},
    );
  }

  Future<Json> profile() async {
    final result = await db.from('profiles').select().eq('id', userId).single();
    accessRole = result['role'] as String;
    return result;
  }

  Future<CashDay> cashDay(DateTime date) async {
    if (!canManageCash) {
      throw StateError('Kas harian hanya untuk owner dan admin.');
    }
    return CashDay.fromJson(
      Json.from(
        await db.rpc('cash_day', params: {'p_date': cashDate(date)}) as Map,
      ),
    );
  }

  Future<List<Json>> wageOverview(Period period) async {
    if (!canViewWages) {
      throw StateError('Akses pembayaran ongkos tidak tersedia.');
    }
    final result = await db.rpc(
      'wage_overview',
      params: {
        'p_start': period.start.toIso8601String(),
        'p_end': period.end.toIso8601String(),
      },
    );
    return (result as List).map((row) => Json.from(row as Map)).toList();
  }

  Future<WageLedger> wageLedger(String workerId, Period period) async {
    if (!canViewWages) {
      throw StateError('Akses pembayaran ongkos tidak tersedia.');
    }
    return WageLedger.fromJson(
      Json.from(
        await db.rpc(
              'wage_ledger',
              params: {
                'p_worker': workerId,
                'p_start': period.start.toIso8601String(),
                'p_end': period.end.toIso8601String(),
              },
            )
            as Map,
      ),
    );
  }

  Future<Json> payWages({
    required String id,
    required WageLedger ledger,
    required Period period,
    required int amount,
    required String method,
    DateTime? paidAt,
    required String notes,
  }) async {
    if (accessRole != 'owner') {
      throw StateError('Hanya owner yang dapat mencatat pembayaran ongkos.');
    }
    return Json.from(
      await db.rpc(
            'pay_wages',
            params: {
              'p_id': id,
              'p_worker': ledger.workerId,
              'p_start': period.start.toIso8601String(),
              'p_end': period.end.toIso8601String(),
              'p_fingerprint': ledger.fingerprint,
              'p_amount': amount,
              'p_method': method,
              'p_paid_at': paidAt?.toUtc().toIso8601String(),
              'p_notes': notes.trim(),
            },
          )
          as Map,
    );
  }

  Future<void> voidWagePayout(String id, String reason) async {
    if (accessRole != 'owner') {
      throw StateError('Hanya owner yang dapat mengoreksi pembayaran ongkos.');
    }
    await db.rpc(
      'void_wage_payout',
      params: {'p_id': id, 'p_reason': reason.trim()},
    );
  }

  Future<Json> closeCash({
    required String id,
    required CashDay day,
    required int opening,
    required int cashOut,
    required int counted,
    required String notes,
  }) async {
    if (!canManageCash) {
      throw StateError('Tutup kas hanya untuk owner dan admin.');
    }
    return Json.from(
      await db.rpc(
            'save_cash_closing',
            params: {
              'p_id': id,
              'p_date': cashDate(day.date),
              'p_previous_id': day.closing?['id'],
              'p_fingerprint': day.fingerprint,
              'p_opening': opening,
              'p_cash_out': cashOut,
              'p_counted': counted,
              'p_notes': notes.trim(),
            },
          )
          as Map,
    );
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
  Future<List<Json>> staff() async {
    final result = await db.rpc('staff_directory');
    return (result as List).map((row) => Json.from(row as Map)).toList();
  }

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
      // A Dart List is encoded as a PostgreSQL array by contains(). The items
      // column is JSONB, so send the JSON array as an encoded string instead.
      query = query.contains(
        'items',
        jsonEncode([
          {'worker_id': workerId},
        ]),
      );
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
        query = query.contains(
          'items',
          jsonEncode([
            {'worker_id': workerId},
          ]),
        );
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
      order.containsKey('due_date')
          ? 'save_order_with_estimate'
          : 'save_order_with_date',
      params: {
        'p_id': order['id'],
        'p_version': order['version'] ?? 0,
        'p_customer': order['customer_name'],
        'p_phone': order['phone'],
        'p_notes': order['notes'],
        'p_discount': order['discount'],
        'p_items': order['items'],
        'p_order_at': order['created_at'],
        if (order.containsKey('due_date')) 'p_due_date': order['due_date'],
      },
    );
  }

  Future<List<Json>> workQueue(
    DeadlineFilter filter,
    int page, {
    String? workerId,
  }) async {
    final result = await db.rpc(
      'work_queue',
      params: {'p_filter': filter.name, 'p_page': page, 'p_worker': workerId},
    );
    return (result as List).map((row) => Json.from(row as Map)).toList();
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

  Future<void> updateOrderStatuses(
    String orderId,
    int version,
    List<Json> statuses,
  ) async {
    await db.rpc(
      'update_order_statuses',
      params: {'p_id': orderId, 'p_version': version, 'p_statuses': statuses},
    );
  }

  Future<void> _deleteOrder(Json order, String reason) async {
    await db.rpc(
      'delete_order',
      params: {
        'p_id': order['id'],
        'p_version': order['version'],
        'p_reason': reason,
      },
    );
  }

  Future<void> delete(Json selected, String reason) async {
    try {
      // Migration 005 deletes the order and corrects payments atomically.
      await _deleteOrder(selected, reason);
      return;
    } on PostgrestException catch (error) {
      // Older deployments require payment corrections before deletion. Perform
      // those owner-authorized corrections automatically after confirmation.
      if (error.code != 'P0001' ||
          !error.message.startsWith('Masih ada pembayaran.')) {
        rethrow;
      }
    }
    final current = await order(selected['id'] as String);
    if (current['version'] != selected['version']) {
      throw StateError('Order berubah. Muat ulang terlebih dahulu.');
    }
    var expectedVersion = money(current['version']);
    final payments =
        ((current['payments'] as List?) ?? [])
            .where((payment) => payment['voided_at'] == null)
            .toList();
    for (final payment in payments) {
      await voidPayment(payment['id'] as String, 'Order dihapus: $reason');
      expectedVersion++;
    }
    final refreshed = await order(selected['id'] as String);
    // Only our payment corrections may advance the version. Concurrent edits
    // or new payments still require a fresh confirmation for the changed order.
    if (refreshed['version'] != expectedVersion) {
      throw StateError('Order berubah. Muat ulang terlebih dahulu.');
    }
    await _deleteOrder(refreshed, reason);
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

  Future<void> deleteEmployee(Json person, String reason) async {
    if (accessRole != 'owner' ||
        person['id'] == userId ||
        person['role'] == 'owner') {
      throw const EmployeeDeletionFailure(
        'Hanya owner yang dapat menghapus akun pegawai lain. Akun owner dilindungi.',
      );
    }
    final text = reason.trim();
    if (text.length < 5 || text.length > 500) {
      throw const EmployeeDeletionFailure(
        'Isi alasan penghapusan 5 sampai 500 karakter.',
      );
    }
    try {
      final response = await db.functions.invoke(
        'delete-employee-account',
        body: {
          'id': person['id'],
          'expected_role': person['role'],
          'reason': text,
        },
      );
      if (response.data is! Map ||
          response.data['deleted'] != true ||
          response.data['id'] != person['id']) {
        throw const EmployeeDeletionFailure(
          'Penghapusan belum dapat dipastikan. Muat ulang daftar pegawai lalu coba pada akun yang sama.',
        );
      }
    } on FunctionException catch (error) {
      if (error.status == 404) {
        throw const EmployeeDeletionFailure(
          'Deploy fungsi delete-employee-account setelah menjalankan 013_delete_employee_account.sql terlebih dahulu.',
        );
      }
      final detail = error.details;
      throw EmployeeDeletionFailure(
        detail is Map && detail['error'] is String
            ? detail['error'] as String
            : 'Penghapusan belum dapat dipastikan. Periksa daftar pegawai dan coba lagi pada akun yang sama.',
        pending: detail is Map && detail['pending'] == true,
      );
    }
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

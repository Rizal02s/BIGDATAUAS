import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:perona_pos/domain.dart';
import 'package:perona_pos/report_data.dart';
import 'package:perona_pos/wage_payments.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_page_test.dart' show pumpHome, capture, loadPreviewFonts;
import 'wage_detail_test.dart' show WageDetailRepository, openWages, tapVisible;

class PayoutRepository extends WageDetailRepository {
  final payouts = <Json>[], calls = <Json>[];
  final ledgerReads = <(String, Period)>[];
  bool failWages = false, loseResponse = false;
  Completer<void>? gate;
  PayoutRepository({super.count});

  WageLedger buildLedger(String worker, Period period) {
    final scoped =
        rows
            .where(
              (r) => period.contains(DateTime.parse(r['created_at'] as String)),
            )
            .toList();
    final notes = <Json>[];
    for (final row in scoped) {
      final earned =
          row['deleted_at'] != null ? 0 : WorkerReport([row], worker).total;
      final linked =
          payouts
              .where(
                (p) =>
                    p['worker_id'] == worker &&
                    (p['allocations'] as List).any(
                      (a) => a['order_id'] == row['id'],
                    ),
              )
              .toList();
      if (earned == 0 && linked.isEmpty) continue;
      final paid = linked
          .where((p) => p['voided_at'] == null)
          .fold<int>(
            0,
            (s, p) =>
                s +
                (p['allocations'] as List)
                    .where((a) => a['order_id'] == row['id'])
                    .fold<int>(0, (s, a) => s + money(a['amount'])),
          );
      notes.add({
        'order_id': row['id'],
        'order_number': row['number'],
        'customer_name': row['customer_name'],
        'order_at': row['created_at'],
        'earned': earned,
        'paid': paid,
        'remaining': (earned - paid).clamp(0, 1000000000000),
        'excess': (paid - earned).clamp(0, 1000000000000),
        'services': 'Deep Clean × 2\nFast Clean × 3',
        'deleted': row['deleted_at'] != null,
      });
    }
    notes.sort(
      (a, b) => (a['order_at'] as String).compareTo(b['order_at'] as String),
    );
    final history = <Json>[];
    for (final p in payouts.where((p) => p['worker_id'] == worker)) {
      final allocations =
          (p['allocations'] as List)
              .where((a) => scoped.any((o) => o['id'] == a['order_id']))
              .toList();
      if (allocations.isNotEmpty) {
        history.add({
          ...p,
          'allocations': allocations,
          'allocated_amount': allocations.fold<int>(
            0,
            (s, a) => s + money(a['amount']),
          ),
        });
      }
    }
    int sum(String f) => notes.fold<int>(0, (s, n) => s + money(n[f]));
    return WageLedger.fromJson({
      'worker_id': worker,
      'worker_name': worker == 'staff-a' ? 'Dina' : 'Bagas',
      'fingerprint': jsonEncode(notes),
      'earned': sum('earned'),
      'paid': sum('paid'),
      'remaining': sum('remaining'),
      'excess': sum('excess'),
      'notes': notes,
      'history': history.reversed.toList(),
    });
  }

  @override
  Future<List<Json>> wageOverview(Period period) async {
    if (failWages) {
      throw const PostgrestException(
        code: 'PGRST202',
        message: 'Could not find public.wage_overview',
      );
    }
    return [
      for (final id in ['staff-a', 'staff-b'])
        {
          'worker_id': id,
          'worker_name': buildLedger(id, period).workerName,
          'earned': buildLedger(id, period).earned,
          'paid': buildLedger(id, period).paid,
          'remaining': buildLedger(id, period).remaining,
          'excess': buildLedger(id, period).excess,
        },
    ];
  }

  @override
  Future<WageLedger> wageLedger(String workerId, Period period) async {
    ledgerReads.add((workerId, period));
    if (failWages) throw StateError('Koneksi rincian terputus.');
    return buildLedger(workerId, period);
  }

  @override
  Future<Json> payWages({
    required String id,
    required WageLedger ledger,
    required Period period,
    required int amount,
    required String method,
    DateTime? paidAt,
    required String notes,
  }) async {
    calls.add({
      'id': id,
      'worker': ledger.workerId,
      'amount': amount,
      'method': method,
      'paid_at': paidAt?.toIso8601String(),
      'notes': notes,
    });
    if (gate != null) await gate!.future;
    final existing = payouts.where((p) => p['id'] == id);
    if (existing.isNotEmpty) return existing.single;
    final fresh = buildLedger(ledger.workerId, period);
    if (fresh.fingerprint != ledger.fingerprint) {
      throw const PostgrestException(
        message:
            'Data ongkos atau pembayaran berubah. Muat ulang sebelum menyimpan.',
      );
    }
    final allocated = <Json>[];
    var left = amount;
    for (final n in fresh.notes) {
      final available = money(n['remaining']);
      final take = left < available ? left : available;
      if (take > 0) {
        allocated.add({
          'order_id': n['order_id'],
          'order_number': n['order_number'],
          'customer_name': n['customer_name'],
          'amount': take,
        });
      }
      left -= take;
      if (left == 0) break;
    }
    final saved = <String, dynamic>{
      'id': id,
      'worker_id': ledger.workerId,
      'amount': amount,
      'method': method,
      'paid_at': (paidAt ?? DateTime.now().toUtc()).toIso8601String(),
      'notes': notes,
      'operator_name': 'Rizal',
      'allocations': allocated,
    };
    payouts.add(saved);
    if (loseResponse) {
      loseResponse = false;
      throw StateError('Respons pembayaran terputus.');
    }
    return saved;
  }

  @override
  Future<void> voidWagePayout(String id, String reason) async {
    final row = payouts.firstWhere((p) => p['id'] == id);
    row['voided_at'] = DateTime.now().toUtc().toIso8601String();
    row['void_reason'] = reason;
  }
}

Future<void> openBook(
  WidgetTester tester,
  PayoutRepository repo, {
  String role = 'owner',
  Size size = const Size(412, 892),
  double scale = 1,
}) async {
  await pumpHome(tester, repo, role, size: size, textScale: scale);
  await tester.tap(find.text('Ongkos'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Bulanan'));
  await tester.pumpAndSettle();
  await tapVisible(tester, find.byKey(const ValueKey('open-wage-payments')));
}

Future<void> openWorker(WidgetTester tester) =>
    tapVisible(tester, find.byKey(const ValueKey('wage-balance-staff-a')));
Future<void> startPay(WidgetTester tester) =>
    tapVisible(tester, find.byKey(const ValueKey('pay-wages')));
Future<void> savePay(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('save-wage-payment')));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadPreviewFonts);
  testWidgets(
    'overview and recipient show entitlement paid remaining and original notes',
    (tester) async {
      final repo = PayoutRepository();
      await openBook(tester, repo);
      expect(find.text('Ongkos tim'), findsOneWidget);
      expect(find.text('Rp90.000'), findsNWidgets(2));
      await capture(tester, 'wage-payments-overview');
      await openWorker(tester);
      expect(find.text('Dina'), findsOneWidget);
      expect(find.text('Rp70.000'), findsWidgets);
      expect(find.text('Belum ada pembayaran ongkos.'), findsOneWidget);
      await capture(tester, 'wage-payment-detail');
      await tapVisible(
        tester,
        find.byKey(const ValueKey('wage-payment-note-order-1')),
      );
      expect(find.text('Detail order'), findsOneWidget);
    },
  );
  testWidgets(
    'owner pays partial then remaining amount and sees date method and allocations',
    (tester) async {
      final repo = PayoutRepository();
      await openBook(tester, repo);
      await openWorker(tester);
      await startPay(tester);
      await tester.enterText(
        find.byKey(const ValueKey('wage-payment-amount')),
        '20000',
      );
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Transfer').last);
      await tester.pumpAndSettle();
      await capture(tester, 'wage-payment-form');
      await savePay(tester);
      expect(repo.payouts, hasLength(1));
      expect(repo.calls.single['method'], 'Transfer');
      expect(find.text('Rp50.000'), findsWidgets);
      expect(find.textContaining('Transfer'), findsWidgets);
      expect(find.textContaining('Nota #1'), findsWidgets);
      await startPay(tester);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('wage-payment-amount')),
            )
            .controller!
            .text,
        '50000',
      );
      await savePay(tester);
      expect(
        repo
            .buildLedger('staff-a', Period.forDate(repo.month, 'month'))
            .remaining,
        0,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('pay-wages')))
            .onPressed,
        isNull,
      );
    },
  );
  testWidgets(
    'invalid zero and excessive amounts do not save and cancel changes nothing',
    (tester) async {
      final repo = PayoutRepository();
      await openBook(tester, repo);
      await openWorker(tester);
      await startPay(tester);
      for (final value in ['0', '70001']) {
        await tester.enterText(
          find.byKey(const ValueKey('wage-payment-amount')),
          value,
        );
        await savePay(tester);
        expect(repo.payouts, isEmpty);
        expect(find.textContaining('Isi nominal lebih dari 0'), findsOneWidget);
      }
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(repo.calls, isEmpty);
    },
  );
  testWidgets('historical payment chooses date and time in WIB', (
    tester,
  ) async {
    final repo = PayoutRepository();
    await openBook(tester, repo);
    await openWorker(tester);
    await startPay(tester);
    await tester.tap(find.byKey(const ValueKey('wage-paid-at')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Switch to input'));
    await tester.pumpAndSettle();
    final now = jakarta(DateTime.now()),
        yesterday = DateTime(now.year, now.month, now.day - 1);
    await tester.enterText(
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.byType(TextField),
      ),
      DateFormat('MM/dd/yyyy').format(yesterday),
    );
    await tester.tap(find.text('Pilih'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK').last);
    await tester.pumpAndSettle();
    await savePay(tester);
    final paid = jakarta(
      DateTime.parse(repo.calls.single['paid_at'] as String),
    );
    expect(
      [paid.year, paid.month, paid.day],
      [yesterday.year, yesterday.month, yesterday.day],
    );
  });
  testWidgets('lost response retry reuses payment ID and ignores double tap', (
    tester,
  ) async {
    final repo = PayoutRepository()..loseResponse = true;
    await openBook(tester, repo);
    await openWorker(tester);
    await startPay(tester);
    repo.gate = Completer<void>();
    final save = find.byKey(const ValueKey('save-wage-payment'));
    await tester.tap(save);
    await tester.pump();
    await tester.tap(save);
    await tester.pump();
    expect(repo.calls, hasLength(1));
    repo.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Coba simpan lagi'), findsOneWidget);
    await savePay(tester);
    expect(repo.calls, hasLength(2));
    expect(repo.calls.first, repo.calls.last);
    expect(repo.payouts, hasLength(1));
  });
  testWidgets(
    'changed entitlement rejects stale payout then reloads current balances',
    (tester) async {
      final repo = PayoutRepository();
      await openBook(tester, repo);
      await openWorker(tester);
      await startPay(tester);
      repo.rows.first['items'][0]['labor_fee'] = 15000;
      await savePay(tester);
      expect(
        find.textContaining('Data ongkos atau pembayaran berubah'),
        findsOneWidget,
      );
      expect(repo.payouts, isEmpty);
      await tester.tap(find.text('Muat ulang'));
      await tester.pumpAndSettle();
      expect(find.text('Rp80.000'), findsWidgets);
    },
  );
  testWidgets(
    'owner correction requires reason restores balance and keeps payment history',
    (tester) async {
      final repo = PayoutRepository();
      await openBook(tester, repo);
      await openWorker(tester);
      await startPay(tester);
      await savePay(tester);
      await tapVisible(
        tester,
        find.byKey(ValueKey('void-wage-${repo.payouts.single['id']}')),
      );
      await tester.enterText(
        find.byType(TextFormField),
        'Salah nominal dicatat',
      );
      await tester.tap(find.text('Konfirmasi'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Dikoreksi'), findsOneWidget);
      expect(repo.payouts, hasLength(1));
      expect(
        repo
            .buildLedger('staff-a', Period.forDate(repo.month, 'month'))
            .remaining,
        70000,
      );
    },
  );
  testWidgets(
    'technician reads history without pay controls and admin has no entry',
    (tester) async {
      final repo = PayoutRepository();
      await openBook(tester, repo, role: 'staff');
      await openWorker(tester);
      expect(find.byKey(const ValueKey('pay-wages')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpHome(tester, repo, 'admin');
      expect(find.byKey(const ValueKey('open-wage-payments')), findsNothing);
    },
  );
  testWidgets(
    'missing migration retries and layout handles small screen with enlarged text',
    (tester) async {
      final repo = PayoutRepository()..failWages = true;
      await openBook(tester, repo, size: const Size(320, 740), scale: 1.5);
      expect(find.textContaining('008_wage_payments.sql'), findsOneWidget);
      repo.failWages = false;
      await tapVisible(tester, find.text('Coba lagi'));
      await openWorker(tester);
      await startPay(tester);
      expect(tester.takeException(), isNull);
      await tester.enterText(
        find.byKey(const ValueKey('wage-payment-amount')),
        '20000',
      );
      await savePay(tester);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'range calendar keeps payouts allocated when switching from month to day',
    (tester) async {
      final repo = PayoutRepository();
      await openBook(tester, repo);
      await openWorker(tester);
      await startPay(tester);
      await tester.enterText(
        find.byKey(const ValueKey('wage-payment-amount')),
        '20000',
      );
      await savePay(tester);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tapVisible(
        tester,
        find.byKey(const ValueKey('wage-payment-period')),
      );
      await tester.tap(find.byTooltip('Switch to input'));
      await tester.pumpAndSettle();
      final mm = repo.month.month.toString().padLeft(2, '0'),
          day = '$mm/01/${repo.month.year}';
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), day);
      await tester.enterText(fields.at(1), day);
      await tester.tap(find.text('Terapkan').last);
      await tester.pumpAndSettle();
      await openWorker(tester);
      expect(find.text('Rp20.000'), findsWidgets);
      expect(find.text('Rp15.000'), findsWidgets);
    },
  );
  testWidgets(
    'worker note detail links to payout page and many notes can load more',
    (tester) async {
      final repo = PayoutRepository(count: 61);
      await openWages(tester, repo);
      await tapVisible(
        tester,
        find.byKey(const ValueKey('worker-wage-staff-a')),
      );
      await tapVisible(
        tester,
        find.byKey(const ValueKey('worker-wage-payments')),
      );
      expect(find.text('Rincian pembayaran ongkos'), findsOneWidget);
      final additional =
          repo
              .buildLedger('staff-a', Period.forDate(repo.month, 'month'))
              .notes[20]['order_id'];
      await tapVisible(tester, find.byKey(const ValueKey('more-wage-notes')));
      final target = find.byKey(ValueKey('wage-payment-note-$additional'));
      await tester.scrollUntilVisible(
        target,
        400,
        maxScrolls: 90,
        scrollable: find.byType(Scrollable).first,
      );
      expect(target, findsOneWidget);
    },
  );
  testWidgets(
    'reduced wage on a paid note displays excess without losing history',
    (tester) async {
      final repo = PayoutRepository();
      await openBook(tester, repo);
      await openWorker(tester);
      await startPay(tester);
      await savePay(tester);
      repo.rows.first['items'][0]['labor_fee'] = 5000;
      await tester.tap(find.byTooltip('Muat ulang'));
      await tester.pumpAndSettle();
      expect(find.text('Kelebihan perlu diperiksa'), findsOneWidget);
      expect(find.text('Rp10.000'), findsWidgets);
      expect(repo.payouts, hasLength(1));
      expect(
        find.textContaining('Ada pembayaran melebihi hak ongkos'),
        findsOneWidget,
      );
    },
  );
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:perona_pos/cash_data.dart';
import 'package:perona_pos/domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_page_test.dart'
    show DemoRepository, pumpHome, capture, loadPreviewFonts;
import 'report_data_test.dart' show sampleOrder;
import 'wage_detail_test.dart' show tapVisible;

class CashRepository extends DemoRepository {
  final today = jakarta(DateTime.now());
  final payments = <Json>[];
  final closings = <String, Json>{}, byId = <String, Json>{};
  final saves = <Json>[];
  final dates = <DateTime>[];
  bool failCash = false, loseResponse = false;
  Completer<void>? gate;

  CashRepository() {
    for (final sample in [
      ('cash', 'Tunai', 30000),
      ('qris', 'QRIS', 50000),
      ('transfer', 'Transfer', 20000),
    ]) {
      payments.add({
        'id': sample.$1,
        'amount': sample.$3,
        'method': sample.$2,
        'paid_at':
            DateTime.utc(
              today.year,
              today.month,
              today.day,
              3,
            ).toIso8601String(),
        'order_id': 'old-note',
        'order_number': 42,
        'customer_name': 'Customer nota lama',
        'order_at':
            DateTime.utc(today.year, today.month - 1, 1, 3).toIso8601String(),
      });
    }
  }

  CashDay buildCashDay(DateTime date) {
    final period = Period.forDate(date, 'day');
    final rows =
        payments
            .where(
              (p) =>
                  p['voided_at'] == null &&
                  period.contains(DateTime.parse(p['paid_at'] as String)),
            )
            .toList();
    int sum(String? method) => rows
        .where((p) => method == null || p['method'] == method)
        .fold<int>(0, (s, p) => s + money(p['amount']));
    return CashDay.fromJson({
      'date': cashDate(date),
      'cash': sum('Tunai'),
      'qris': sum('QRIS'),
      'transfer': sum('Transfer'),
      'total': sum(null),
      'count': rows.length,
      'payments': rows,
      'fingerprint': rows.map((p) => '${p['id']}:${p['amount']}').join('|'),
      'closing': closings[cashDate(date)],
    });
  }

  @override
  Future<CashDay> cashDay(DateTime date) async {
    dates.add(date);
    if (failCash) throw StateError('Koneksi kas terputus.');
    return buildCashDay(date);
  }

  @override
  Future<Json> closeCash({
    required String id,
    required CashDay day,
    required int opening,
    required int cashOut,
    required int counted,
    required String notes,
  }) async {
    saves.add({
      'id': id,
      'previous': day.closing?['id'],
      'opening': opening,
      'out': cashOut,
      'counted': counted,
      'notes': notes,
    });
    if (gate != null) await gate!.future;
    if (byId.containsKey(id)) return byId[id]!;
    if (day.fingerprint != buildCashDay(day.date).fingerprint) {
      throw const PostgrestException(
        message: 'Data pembayaran telah berubah. Muat ulang sebelum tutup kas.',
      );
    }
    final saved = <String, dynamic>{
      'id': id,
      'business_date': cashDate(day.date),
      'previous_id': day.closing?['id'],
      'opening_cash': opening,
      'cash_out': cashOut,
      'counted_cash': counted,
      'cash_received': day.cash,
      'qris_received': day.qris,
      'transfer_received': day.transfer,
      'expected_cash': opening + day.cash - cashOut,
      'difference': counted - opening - day.cash + cashOut,
      'source_fingerprint': day.fingerprint,
      'notes': notes,
      'operator_name': 'Petugas kas',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    byId[id] = saved;
    closings[cashDate(day.date)] = saved;
    if (loseResponse) {
      loseResponse = false;
      throw StateError('Respons terputus.');
    }
    return saved;
  }

  @override
  Future<Json> order(String id) async => {
    ...sampleOrder(createdAt: payments.first['order_at'] as String),
    'id': id,
    'number': 42,
    'customer_name': 'Customer nota lama',
    'notes': '',
    'payments': [],
  };
}

Future<void> openCash(
  WidgetTester tester,
  CashRepository repo, {
  String role = 'owner',
  Size size = const Size(412, 892),
  double scale = 1,
}) async {
  await pumpHome(tester, repo, role, size: size, textScale: scale);
  await tapVisible(tester, find.byKey(const ValueKey('open-daily-cash')));
}

Future<void> enterAmount(WidgetTester tester, String key, String value) async {
  final target = find.byKey(ValueKey(key));
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.3);
  await tester.pumpAndSettle();
  await tester.enterText(target, value);
  await tester.pumpAndSettle();
}

Future<void> startClosing(WidgetTester tester) =>
    tapVisible(tester, find.byKey(const ValueKey('close-daily-cash')));

void main() {
  setUpAll(loadPreviewFonts);

  testWidgets(
    'cash page shows received dates and methods including old notes and opens their order',
    (tester) async {
      final repo = CashRepository();
      await openCash(tester, repo);
      expect(find.text('Kas harian'), findsOneWidget);
      expect(find.text('Rp100.000'), findsOneWidget);
      expect(find.text('3 pembayaran'), findsOneWidget);
      expect(find.text('Tunai diterima'), findsOneWidget);
      expect(find.text('QRIS diterima'), findsOneWidget);
      expect(find.text('Transfer diterima'), findsOneWidget);
      await capture(tester, 'daily-cash');
      await tapVisible(tester, find.widgetWithText(ChoiceChip, 'QRIS'));
      expect(find.text('Nota #42 · QRIS'), findsOneWidget);
      expect(find.text('Nota #42 · Tunai'), findsNothing);
      await tapVisible(tester, find.text('Nota #42 · QRIS'));
      expect(find.text('Detail order'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(repo.dates.length, 2);
    },
  );

  testWidgets(
    'close records opening outflow actual cash and a required discrepancy note',
    (tester) async {
      final repo = CashRepository();
      await openCash(tester, repo);
      await startClosing(tester);
      await enterAmount(tester, 'cash-opening', '100000');
      await enterAmount(tester, 'cash-out', '10000');
      await enterAmount(tester, 'cash-counted', '119000');
      expect(find.text('Tunai seharusnya Rp120.000'), findsOneWidget);
      expect(find.text('Kurang Rp1.000'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('save-cash-closing')));
      await tester.pumpAndSettle();
      expect(repo.saves, isEmpty);
      await enterAmount(tester, 'cash-notes', 'Selisih uang kembalian');
      expect(
        find.text('Isi minimal 5 karakter untuk selisih atau pembaruan.'),
        findsNothing,
      );
      await capture(tester, 'cash-closing-form');
      await tester.tap(find.byKey(const ValueKey('save-cash-closing')));
      await tester.pumpAndSettle();
      expect(repo.byId, hasLength(1));
      expect(repo.saves.single['counted'], 119000);
      expect(find.text('Tutup kas tersimpan'), findsOneWidget);
      expect(find.text('Kurang Rp1.000'), findsOneWidget);
      await capture(tester, 'cash-closing-saved');
    },
  );

  testWidgets(
    'new payments flag saved closing and owner revision keeps previous link',
    (tester) async {
      final repo = CashRepository();
      await openCash(tester, repo);
      await startClosing(tester);
      await enterAmount(tester, 'cash-counted', '30000');
      await tester.tap(find.byKey(const ValueKey('save-cash-closing')));
      await tester.pumpAndSettle();
      final first = repo.byId.keys.single;
      repo.payments.add({
        ...repo.payments.first,
        'id': 'later',
        'amount': 5000,
      });
      await tester.tap(find.byTooltip('Muat ulang'));
      await tester.pumpAndSettle();
      expect(find.text('Perlu periksa ulang'), findsOneWidget);
      await startClosing(tester);
      await enterAmount(tester, 'cash-counted', '35000');
      await enterAmount(tester, 'cash-notes', 'Pembayaran susulan dicatat');
      await tester.tap(find.byKey(const ValueKey('save-cash-closing')));
      await tester.pumpAndSettle();
      expect(repo.byId, hasLength(2));
      expect(repo.saves.last['previous'], first);
      expect(find.text('Perlu periksa ulang'), findsNothing);
      expect(find.text('Tutup kas tersimpan'), findsOneWidget);
    },
  );

  testWidgets(
    'lost response retries same request without duplicate close and double tap is ignored',
    (tester) async {
      final repo = CashRepository()..loseResponse = true;
      await openCash(tester, repo);
      await startClosing(tester);
      await enterAmount(tester, 'cash-counted', '30000');
      repo.gate = Completer<void>();
      final save = find.byKey(const ValueKey('save-cash-closing'));
      await tester.tap(save);
      await tester.pump();
      await tester.tap(save);
      await tester.pump();
      expect(repo.saves, hasLength(1));
      repo.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Coba simpan lagi'), findsOneWidget);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(repo.saves, hasLength(2));
      expect(repo.saves.first, repo.saves.last);
      expect(repo.byId, hasLength(1));
      expect(find.text('Tutup kas tersimpan'), findsOneWidget);
    },
  );

  testWidgets(
    'stale receipt snapshot is rejected and can reload without saving',
    (tester) async {
      final repo = CashRepository();
      await openCash(tester, repo);
      await startClosing(tester);
      await enterAmount(tester, 'cash-counted', '30000');
      repo.payments.add({
        ...repo.payments.first,
        'id': 'concurrent',
        'amount': 5000,
      });
      await tester.tap(find.byKey(const ValueKey('save-cash-closing')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Data pembayaran telah berubah'),
        findsOneWidget,
      );
      expect(repo.byId, isEmpty);
      await tester.tap(find.text('Muat ulang laporan'));
      await tester.pumpAndSettle();
      expect(find.text('Rp105.000'), findsOneWidget);
    },
  );

  testWidgets('cash dates use calendar and an empty day can be reconciled', (
    tester,
  ) async {
    final repo = CashRepository();
    await openCash(tester, repo);
    await tester.tap(find.byKey(const ValueKey('cash-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Switch to input'));
    await tester.pumpAndSettle();
    final yesterday = DateTime(
      repo.today.year,
      repo.today.month,
      repo.today.day - 1,
    );
    await tester.enterText(
      find.byType(TextField),
      DateFormat('MM/dd/yyyy').format(yesterday),
    );
    await tester.tap(find.text('Pilih').last);
    await tester.pumpAndSettle();
    expect(cashDate(repo.dates.last), cashDate(yesterday));
    expect(find.text('0 pembayaran'), findsOneWidget);
    await startClosing(tester);
    await enterAmount(tester, 'cash-counted', '0');
    await tester.tap(find.byKey(const ValueKey('save-cash-closing')));
    await tester.pumpAndSettle();
    expect(repo.byId, hasLength(1));
  });

  testWidgets(
    'admin can close once and technicians do not get the cash entry',
    (tester) async {
      final repo = CashRepository();
      await openCash(tester, repo, role: 'admin');
      await startClosing(tester);
      await enterAmount(tester, 'cash-counted', '30000');
      await tester.tap(find.byKey(const ValueKey('save-cash-closing')));
      await tester.pumpAndSettle();
      expect(find.text('Perbarui tutup kas'), findsNothing);
      expect(
        find.text('Pembaruan tutup kas dilakukan oleh owner.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpHome(tester, repo, 'staff');
      expect(find.byKey(const ValueKey('open-daily-cash')), findsNothing);
    },
  );

  testWidgets(
    'loading errors retry and cash forms fit narrow phones with enlarged text',
    (tester) async {
      final repo = CashRepository()..failCash = true;
      await openCash(tester, repo, size: const Size(320, 740), scale: 1.5);
      expect(find.text('Kas harian belum bisa dimuat'), findsOneWidget);
      repo.failCash = false;
      await tapVisible(tester, find.text('Coba lagi'));
      await startClosing(tester);
      await enterAmount(tester, 'cash-opening', '100000');
      await enterAmount(tester, 'cash-out', '999999');
      await enterAmount(tester, 'cash-counted', '30000');
      await tester.tap(find.byKey(const ValueKey('save-cash-closing')));
      await tester.pumpAndSettle();
      expect(repo.saves, isEmpty);
      expect(find.text('Melebihi kas yang tersedia.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'payment list shows entries beyond thirty with correct full totals',
    (tester) async {
      final repo = CashRepository();
      final original = repo.payments.first;
      repo.payments.clear();
      for (var i = 0; i < 61; i++) {
        repo.payments.add({...original, 'id': 'payment-$i', 'amount': 1000});
      }
      await openCash(tester, repo);
      expect(find.text('61 pembayaran'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('cash-total'))).data,
        'Rp61.000',
      );
      await tapVisible(
        tester,
        find.byKey(const ValueKey('cash-more-payments')),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('cash-more-payments')),
        400,
        maxScrolls: 90,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Tampilkan lagi (1 pembayaran)'), findsOneWidget);
      await tapVisible(
        tester,
        find.byKey(const ValueKey('cash-more-payments')),
      );
      expect(
        find.byKey(const ValueKey('cash-payment-payment-60')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('cash-more-payments')), findsNothing);
    },
  );
}

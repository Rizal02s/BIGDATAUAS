import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perona_pos/domain.dart';
import 'package:perona_pos/operational_report.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_page_test.dart' show pumpHome, capture, loadPreviewFonts;
import 'order_detail_test.dart' show DetailRepository;
import 'pdf_test_support.dart';
import 'package:printing/src/interface.dart';
import 'package:file_picker/file_picker.dart';

class AdminReportRepository extends DetailRepository {
  final reads = <(Period, int)>[];
  bool failReport = false, failMore = false;
  int paymentCount = 1;
  @override
  Future<OperationalReport> operationalReport(
    Period period, {
    int page = 0,
  }) async {
    reads.add((period, page));
    if (failReport || (failMore && page > 0)) {
      throw const PostgrestException(
        code: 'PGRST202',
        message: 'Missing operational_report',
      );
    }
    return OperationalReport.fromJson({
      'count': 3,
      'gross': 240000,
      'revenue': 230000,
      'discount': 10000,
      'pending': 1,
      'ready': 1,
      'picked_up': 1,
      'overdue': 1,
      'due_today': 0,
      'outstanding_period': 40000,
      'outstanding_all': 180000,
      'received': 120000,
      'cash': 80000,
      'qris': 20000,
      'transfer': 20000,
      'receipt_count': paymentCount,
      'payments':
          List.generate(
            paymentCount,
            (i) => {
              'id': 'receipt-$i',
              'order_id': 'order-a',
              'customer_name': 'Customer bayar ${i + 1}',
              'order_number': 24,
              'amount': 30000,
              'method': 'Tunai',
              'paid_at':
                  period.start.add(const Duration(hours: 1)).toIso8601String(),
              'order_at': '2026-10-03T03:15:00Z',
              'operator_name': 'Dina',
            },
          ).skip(page * 30).take(30).toList(),
    });
  }
}

Future<void> visible(
  WidgetTester tester,
  Finder target, {
  double step = 350,
}) async {
  await tester.scrollUntilVisible(
    target,
    step,
    maxScrolls: 100,
    scrollable: find.byType(Scrollable).first,
  );
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.35);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadPreviewFonts);
  testWidgets(
    'Admin has four operational tabs and catalog shows only customer prices',
    (tester) async {
      final repo = AdminReportRepository();
      await pumpHome(tester, repo, 'admin');
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.destinations.map((d) => (d as NavigationDestination).label), [
        'Beranda',
        'Order',
        'Layanan',
        'Laporan',
      ]);
      expect(find.text('Penerimaan pelanggan'), findsOneWidget);
      await capture(tester, 'admin-home');
      await tester.tap(find.text('Layanan'));
      await tester.pumpAndSettle();
      expect(find.text('Daftar layanan'), findsOneWidget);
      expect(find.text('Harga pelanggan'), findsOneWidget);
      expect(find.text('Rp30.000'), findsOneWidget);
      expect(
        find.textContaining(RegExp('ongkos|internal', caseSensitive: false)),
        findsNothing,
      );
      expect(find.text('Tambah layanan'), findsNothing);
      expect(find.byTooltip('Edit layanan'), findsNothing);
      await capture(tester, 'admin-services');
      await tester.enterText(
        find.byKey(const ValueKey('catalog-search')),
        'tidak ada',
      );
      await tester.pumpAndSettle();
      expect(find.text('Layanan tidak ditemukan'), findsOneWidget);
      expect(repo.reportReads, 0);
    },
  );

  testWidgets(
    'Operational report separates note values receipts and receivables with no payroll data',
    (tester) async {
      final repo = AdminReportRepository();
      await pumpHome(tester, repo, 'admin');
      await tester.tap(find.text('Laporan'));
      await tester.pumpAndSettle();
      expect(find.text('Laporan operasional'), findsOneWidget);
      expect(find.text('Ongkos'), findsNothing);
      expect(find.text('Internal'), findsNothing);
      await capture(tester, 'admin-operational-report');
      await visible(tester, find.text('Omzet nota'));
      expect(find.text('Rp230.000'), findsOneWidget);
      expect(find.text('Sisa tagihan nota periode ini'), findsOneWidget);
      expect(find.text('Rp40.000'), findsOneWidget);
      await visible(tester, find.text('Total penerimaan'));
      expect(find.text('Tunai'), findsOneWidget);
      expect(find.text('QRIS'), findsOneWidget);
      expect(find.text('Transfer'), findsOneWidget);
      expect(
        find.textContaining(
          RegExp('ongkos|gaji|kontribusi|biaya internal', caseSensitive: false),
        ),
        findsNothing,
      );
      await capture(tester, 'admin-receipts-summary');
      expect(repo.reportReads, 0);
    },
  );

  testWidgets(
    'Report receipt opens original customer note and returns to refreshed report',
    (tester) async {
      final repo = AdminReportRepository();
      await pumpHome(tester, repo, 'admin');
      await tester.tap(find.text('Laporan'));
      await tester.pumpAndSettle();
      final target = find.byKey(
        const ValueKey('operational-receipt-receipt-0'),
      );
      await visible(tester, target);
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(find.text('Detail order'), findsOneWidget);
      expect(find.textContaining('Andi Pratama'), findsOneWidget);
      expect(find.text('Hapus order'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Laporan operasional'), findsOneWidget);
      expect(repo.reads.length, greaterThan(2));
    },
  );

  testWidgets(
    'Report supports all payment pages and retries failed next page without losing earlier data',
    (tester) async {
      final repo = AdminReportRepository()..paymentCount = 31;
      await pumpHome(tester, repo, 'admin');
      await tester.tap(find.text('Laporan'));
      await tester.pumpAndSettle();
      final more = find.byKey(const ValueKey('more-operational-receipts'));
      await visible(tester, more, step: 800);
      repo.failMore = true;
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(repo.reads.last.$2, 1);
      expect(find.text('Coba muat laporan'), findsOneWidget);
      repo.failMore = false;
      await visible(tester, find.text('Coba muat laporan'));
      await tester.tap(find.text('Coba muat laporan'));
      await tester.pumpAndSettle();
      await visible(
        tester,
        find.byKey(const ValueKey('operational-receipt-receipt-30')),
      );
      expect(find.text('Customer bayar 31 · Nota #24'), findsOneWidget);
    },
  );

  testWidgets(
    'Day month and year report controls request matching WIB bounds and keep wage report unused',
    (tester) async {
      final repo = AdminReportRepository();
      await pumpHome(tester, repo, 'admin');
      await tester.tap(find.text('Laporan'));
      await tester.pumpAndSettle();
      for (final (label, kind) in [
        ('Bulanan', 'month'),
        ('Tahunan', 'year'),
        ('Harian', 'day'),
      ]) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        final expected = Period.forDate(jakarta(DateTime.now()), kind);
        expect(repo.reads.last.$1.start, expected.start);
        expect(repo.reads.last.$1.end, expected.end);
        expect(repo.reads.last.$2, 0);
      }
      expect(repo.reportReads, 0);
    },
  );

  testWidgets(
    'Missing report migration remains nonblocking for input and catalog then retries',
    (tester) async {
      final repo = AdminReportRepository()..failReport = true;
      await pumpHome(tester, repo, 'admin');
      expect(
        find.textContaining('012_admin_operational_report.sql'),
        findsOneWidget,
      );
      final input = find.text('Input order pelanggan');
      await visible(tester, input);
      await tester.tap(input);
      await tester.pumpAndSettle();
      expect(find.text('Tambah order'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      repo.failReport = false;
      await visible(tester, find.text('Coba muat laporan'));
      await tester.tap(find.text('Coba muat laporan'));
      await tester.pumpAndSettle();
      expect(find.text('Penerimaan pelanggan'), findsOneWidget);
    },
  );

  testWidgets('Admin report and catalog fit 320px with large text', (
    tester,
  ) async {
    final repo = AdminReportRepository();
    await pumpHome(
      tester,
      repo,
      'admin',
      size: const Size(320, 740),
      textScale: 1.5,
    );
    await tester.tap(find.text('Laporan'));
    await tester.pumpAndSettle();
    await visible(
      tester,
      find.byKey(const ValueKey('operational-receipt-receipt-0')),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Layanan'));
    await tester.pumpAndSettle();
    await visible(tester, find.text('Harga pelanggan'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Report page links to existing customer-only order PDF export', (
    tester,
  ) async {
    installPdfTestAssets();
    PrintingPlatform.instance = TestPrinting();
    final picker = TestFilePicker();
    FilePickerPlatform.instance = picker;
    final repo = AdminReportRepository();
    await pumpHome(tester, repo, 'admin');
    await tester.tap(find.text('Laporan'));
    await tester.pumpAndSettle();
    final target = find.byKey(const ValueKey('report-order-pdf'));
    await visible(tester, target);
    await tester.tap(target);
    await tester.pumpAndSettle();
    expect(find.text('PDF rekap order'), findsOneWidget);
    expect(find.textContaining('Laporan internal'), findsNothing);
    await tester.tap(find.text('Unduh PDF'));
    await tester.pumpAndSettle();
    expect(picker.saved.single.length, greaterThan(10000));
  });
}

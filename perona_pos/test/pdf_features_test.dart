import 'dart:typed_data';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perona_pos/app_theme.dart';
import 'package:perona_pos/domain.dart';
import 'package:perona_pos/pdf_export.dart';
import 'package:perona_pos/report_data.dart';
import 'package:printing/src/interface.dart';

import 'home_page_test.dart'
    show DemoRepository, pumpHome, capture, loadPreviewFonts;
import 'order_editor_test.dart' show openEditor, addService;
import 'order_submission_test.dart' show SubmissionRepository;
import 'pdf_test_support.dart';
import 'report_data_test.dart' show sampleOrder;

class ReceiptRepository extends SubmissionRepository {
  bool failReceipt = true;
  int reads = 0;
  @override
  Future<Json> order(String id) async {
    reads++;
    if (failReceipt) throw Exception('Receipt connection failed');
    return {
      ...sampleOrder(),
      'id': id,
      'total': serverTotal,
      'payments': receipts.values.toList(),
    };
  }
}

class WorkRepository extends DemoRepository {
  int exportReads = 0;
  Period? exportedPeriod;
  @override
  Future<List<Json>> allOrders(Period period, {String? workerId}) {
    exportReads++;
    exportedPeriod = period;
    return super.allOrders(period, workerId: workerId);
  }

  @override
  Future<Map<int, int>> orderDayCounts(
    DateTime month, {
    String? workerId,
  }) async => {3: 1};
  @override
  Future<List<Json>> orders(Period period, int page, {String? workerId}) async {
    workerFilters.add(workerId);
    return page == 0
        ? [
          {
            ...sampleOrder(),
            'created_at':
                period.start.add(const Duration(hours: 10)).toIso8601String(),
          },
        ]
        : [];
  }
}

void main() {
  setUpAll(loadPreviewFonts);
  setUp(() {
    installPdfTestAssets();
    PrintingPlatform.instance = TestPrinting();
  });

  for (final role in ['owner', 'admin']) {
    testWidgets(
      '$role downloads the selected monthly report through the order page',
      (tester) async {
        final repo = WorkRepository();
        final picker = TestFilePicker();
        FilePickerPlatform.instance = picker;
        await pumpHome(tester, repo, role);
        await tester.tap(find.text('Order'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Bulanan'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Unduh rekap PDF'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Unduh rekap PDF'));
        await tester.pumpAndSettle();
        expect(find.text('PDF rekap order'), findsOneWidget);
        expect(repo.exportReads, 1);
        expect(
          periodLabel(repo.exportedPeriod!),
          periodLabel(Period.forDate(jakarta(DateTime.now()), 'month')),
        );
        await tester.tap(find.text('Unduh PDF'));
        await tester.pumpAndSettle();
        expect(picker.saved.single.length, greaterThan(10000));
        if (const bool.fromEnvironment('PDF_PREVIEW') && role == 'admin') {
          Directory('tmp/pdfs').createSync(recursive: true);
          File(
            'tmp/pdfs/admin-monthly-ui.pdf',
          ).writeAsBytesSync(picker.saved.single);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'owner input and picker hide wages; receipt failure retries only PDF',
    (tester) async {
      final repo = ReceiptRepository()..accessRole = 'owner';
      await openEditor(tester, repo);
      await tester.enterText(find.byType(TextFormField).first, 'Customer nota');
      await addService(tester);
      expect(
        find.textContaining(RegExp('ongkos', caseSensitive: false)),
        findsNothing,
      );
      await tester.scrollUntilVisible(
        find.text('Simpan & buat nota PDF'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Simpan & buat nota PDF'));
      await tester.pumpAndSettle();
      await capture(tester, 'order-save-receipt');
      await tester.tap(find.text('Simpan & buat nota PDF'));
      await tester.pumpAndSettle();
      expect(repo.saves, 1);
      expect(find.text('Nota pelanggan'), findsOneWidget);
      expect(find.text('Coba buat PDF lagi'), findsOneWidget);
      repo.failReceipt = false;
      await tester.tap(find.text('Coba buat PDF lagi'));
      await tester.pumpAndSettle();
      expect(repo.saves, 1);
      expect(repo.reads, 2);
      expect(find.text('Unduh PDF'), findsOneWidget);
      expect(find.text('Bagikan PDF'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Buat order pengujian'), findsOneWidget);
      expect(repo.saves, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'employee opens complete wage detail with customer and five columns',
    (tester) async {
      final repo = WorkRepository();
      await pumpHome(tester, repo, 'owner');
      await tester.tap(find.text('Ongkos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bulanan'));
      await tester.pumpAndSettle();
      final worker = find.byKey(const ValueKey('worker-wage-staff-a'));
      await tester.scrollUntilVisible(
        worker,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(worker);
      await tester.pumpAndSettle();
      await tester.tap(worker);
      await tester.pumpAndSettle();
      expect(find.text('Ongkos Dina'), findsOneWidget);
      expect(find.text('Rp20.000'), findsWidgets);
      expect(repo.workerFilters.last, 'staff-a');
      await capture(tester, 'employee-wage-detail');
      await tester.scrollUntilVisible(
        find.byType(DataTable),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Customer 1'), findsOneWidget);
      expect(find.text('Deep Clean\nSelesai'), findsOneWidget);
      expect(find.text('Perawatan sepatu kulit\nMasuk'), findsNothing);
      expect(
        tester.widget<DataTable>(find.byType(DataTable)).columns.length,
        5,
      );
      await capture(tester, 'employee-wage-table');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'PDF download saves identical bytes, cancel and failure are retryable; sharing is explicit',
    (tester) async {
      final picker = TestFilePicker();
      FilePickerPlatform.instance = picker;
      final printing = TestPrinting();
      PrintingPlatform.instance = printing;
      final bytes = Uint8List.fromList([37, 80, 68, 70, 45]);
      await tester.pumpWidget(
        MaterialApp(
          theme: peronaTheme(),
          home: PdfExportPage(
            title: 'Nota pelanggan',
            filename: 'nota.pdf',
            description: 'Contoh nota',
            generate: () async => bytes,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(printing.shared, isEmpty);
      picker.cancel = true;
      await tester.tap(find.text('Unduh PDF'));
      await tester.pumpAndSettle();
      expect(picker.saved, isEmpty);
      expect(find.textContaining('PDF berhasil disimpan'), findsNothing);
      picker.cancel = false;
      picker.fail = true;
      await tester.tap(find.text('Unduh PDF'));
      await tester.pumpAndSettle();
      expect(picker.saved, isEmpty);
      picker.fail = false;
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unduh PDF'));
      await tester.pumpAndSettle();
      expect(picker.saved.single, bytes);
      expect(picker.mime, 'application/pdf');
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bagikan PDF'));
      await tester.pumpAndSettle();
      expect(printing.shared.single, bytes);
    },
  );
}

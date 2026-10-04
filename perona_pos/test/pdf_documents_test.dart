import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:perona_pos/domain.dart';
import 'package:perona_pos/pdf_documents.dart';
import 'package:perona_pos/report_data.dart';

import 'report_data_test.dart' show sampleOrder;
import 'pdf_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(installPdfTestAssets);
  test(
    'generate customer receipt, paginated wages and complete monthly PDFs',
    () async {
      final pdf = await PeronaPdf.load();
      final period = Period.forDate(DateTime(2026, 10, 1), 'month');
      final orders = List.generate(45, (i) => sampleOrder(index: i + 1));
      final files = {
        'contoh-nota.pdf': await pdf.receipt(
          CustomerReceipt.fromOrder(orders.first),
        ),
        'contoh-ongkos-pegawai.pdf': await pdf.worker(
          WorkerReport(orders, 'staff-a'),
          'Dina',
          period,
        ),
        'contoh-rekap-oktober.pdf': await pdf.orders(
          OrderReport(orders, includeWages: true),
          period,
        ),
      };
      for (final entry in files.entries) {
        expect(entry.value.take(5), [37, 80, 68, 70, 45]);
        expect(entry.value.length, greaterThan(10000));
        if (const bool.fromEnvironment('PDF_PREVIEW')) {
          Directory('output/pdf').createSync(recursive: true);
          File('output/pdf/${entry.key}').writeAsBytesSync(entry.value);
        }
      }
    },
  );
  test(
    'PDF handles empty reports, long names and many services on one order',
    () async {
      final pdf = await PeronaPdf.load();
      final period = Period.forDate(DateTime(2026, 10, 1), 'month');
      await pdf.orders(OrderReport([], includeWages: true), period);
      await pdf.worker(WorkerReport([], 'staff-a'), 'Dina', period);
      final order = sampleOrder();
      order['customer_name'] = List.filled(10, 'Nama Pelanggan').join(' ');
      order['items'] = List.generate(
        55,
        (i) => {
          ...(sampleOrder()['items'] as List).first as Json,
          'name': 'Perawatan sepatu kulit dan pembersihan menyeluruh nomor $i',
        },
      );
      await pdf.receipt(CustomerReceipt.fromOrder(order));
      await pdf.worker(
        WorkerReport([order], 'staff-a'),
        'Nama pegawai yang panjang',
        period,
      );
      final bytes = await pdf.orders(
        OrderReport([order], includeWages: false),
        period,
      );
      if (const bool.fromEnvironment('PDF_PREVIEW')) {
        Directory('tmp/pdfs').createSync(recursive: true);
        File('tmp/pdfs/admin-long-order.pdf').writeAsBytesSync(bytes);
      }
    },
  );
}

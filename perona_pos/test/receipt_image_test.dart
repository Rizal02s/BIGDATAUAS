import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:perona_pos/receipt_image.dart';
import 'package:perona_pos/report_data.dart';

import 'pdf_test_support.dart';
import 'report_data_test.dart' show sampleOrder;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(installPdfTestAssets);

  test(
    'receipt PNG is readable-sized and independent of internal data',
    () async {
      final order = sampleOrder(phone: '081234567890');
      order['due_date'] = '2026-10-05';
      final images = await renderReceiptImages(
        CustomerReceipt.fromOrder(order),
      );
      expect(images, hasLength(1));
      expect(images.single.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      final codec = await ui.instantiateImageCodec(images.single);
      final image = (await codec.getNextFrame()).image;
      expect(image.width, 1080);
      expect(image.height, inInclusiveRange(800, 4800));
      image.dispose();
      codec.dispose();
      final privateChanges = {
        ...order,
        'labor_total': 999999999,
        'notes': 'Catatan internal rahasia',
        'items': [
          for (final item in order['items'])
            {...item, 'labor_fee': 7654321, 'worker_id': 'Teknisi rahasia'},
        ],
      };
      final privateImages = await renderReceiptImages(
        CustomerReceipt.fromOrder(privateChanges),
      );
      expect(privateImages.single, images.single);
      final missingEstimate = await renderReceiptImages(
        CustomerReceipt.fromOrder({...order, 'due_date': null}),
      );
      expect(missingEstimate.single, isNot(images.single));
      if (const bool.fromEnvironment('WRITE_RECEIPT_PREVIEW')) {
        Directory('output/receipts').createSync(recursive: true);
        File('output/receipts/contoh-nota.png').writeAsBytesSync(images.single);
        File(
          'output/receipts/nota-tanpa-estimasi.png',
        ).writeAsBytesSync(missingEstimate.single);
      }
    },
  );

  test('100 services and long names continue across bounded PNGs', () async {
    final order = sampleOrder();
    order['due_date'] = '2026-10-05';
    order['customer_name'] =
        'Pelanggan dengan nama panjang untuk pemeriksaan tampilan nota';
    order['items'] = List.generate(
      100,
      (i) => {
        'name':
            'Layanan ${i + 1} — Deep Clean dan perawatan sepatu kulit dengan penanganan khusus',
        'quantity': 1,
        'price': 30000,
      },
    );
    order['total'] = 2995000;
    final images = await renderReceiptImages(CustomerReceipt.fromOrder(order));
    expect(images.length, greaterThan(1));
    for (final png in images) {
      final codec = await ui.instantiateImageCodec(png);
      final image = (await codec.getNextFrame()).image;
      expect(image.width, 1080);
      expect(image.height, lessThanOrEqualTo(4800));
      image.dispose();
      codec.dispose();
    }
    if (const bool.fromEnvironment('WRITE_RECEIPT_PREVIEW')) {
      Directory('output/receipts').createSync(recursive: true);
      File(
        'output/receipts/nota-panjang-awal.png',
      ).writeAsBytesSync(images.first);
      File(
        'output/receipts/nota-panjang-akhir.png',
      ).writeAsBytesSync(images.last);
    }
  });
}

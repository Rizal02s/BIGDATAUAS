// Android PDF smoke test with demo data. Does not connect to Supabase.
// flutter run -t tool/pdf_smoke.dart -d emulator-5554
import 'package:flutter/material.dart';
import 'package:perona_pos/app_theme.dart';
import 'package:perona_pos/pdf_documents.dart';
import 'package:perona_pos/pdf_export.dart';
import 'package:perona_pos/report_data.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: peronaTheme(),
      home: PdfExportPage(
        title: 'Nota pelanggan',
        filename: 'nota-perona-demo.pdf',
        description: 'Data contoh untuk menguji unduhan dan bagikan PDF.',
        generate:
            () async => (await PeronaPdf.load()).receipt(
              CustomerReceipt.fromOrder({
                'id': 'demo',
                'number': 1,
                'customer_name': 'Customer Contoh',
                'phone': '081234567890',
                'created_at': '2026-10-03T03:15:00Z',
                'discount': 0,
                'total': 60000,
                'items': [
                  {'name': 'Deep Clean', 'quantity': 2, 'price': 30000},
                ],
                'payments': [
                  {'amount': 60000, 'method': 'QRIS', 'voided_at': null},
                ],
              }),
            ),
      ),
    ),
  );
}

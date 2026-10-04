import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'domain.dart';
import 'report_data.dart';

class PeronaPdf {
  final pw.Font regular, bold;
  final pw.ImageProvider logo;
  PeronaPdf(this.regular, this.bold, this.logo);
  static Future<PeronaPdf> load() async {
    final assets = await Future.wait([
      rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
      rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
      rootBundle.load('assets/perona-logo.png'),
    ]);
    return PeronaPdf(
      pw.Font.ttf(assets[0]),
      pw.Font.ttf(assets[1]),
      pw.MemoryImage(assets[2].buffer.asUint8List()),
    );
  }

  static final green = PdfColor.fromHex('#58730b');
  static final cream = PdfColor.fromHex('#faf5e7');
  static final ink = PdfColor.fromHex('#2e381e');
  static final muted = PdfColor.fromHex('#747560');
  String rupiah(int n) => NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  ).format(n);
  String date(dynamic raw) => DateFormat(
    'dd/MM/yyyy',
  ).format(jakarta(raw is DateTime ? raw : DateTime.parse(raw as String)));
  pw.Document document(String title) => pw.Document(
    title: title,
    author: 'Perona Sepatu',
    theme: pw.ThemeData.withFont(base: regular, bold: bold).copyWith(
      defaultTextStyle: pw.TextStyle(font: regular, fontSize: 9, color: ink),
    ),
  );

  pw.Widget header(String title, String subtitle, {bool internal = false}) =>
      pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 14),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Image(logo, width: 130, height: 44, fit: pw.BoxFit.contain),
            pw.SizedBox(width: 20),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    title,
                    style: pw.TextStyle(font: bold, fontSize: 18, color: green),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(subtitle, textAlign: pw.TextAlign.right),
                  if (internal) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'INTERNAL - OWNER & TEKNISI',
                      style: pw.TextStyle(fontSize: 7, color: muted),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );

  pw.Widget footer(pw.Context context) => pw.Container(
    padding: const pw.EdgeInsets.only(top: 10),
    decoration: const pw.BoxDecoration(
      border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'Perona Sepatu | Waktu Indonesia Barat (WIB)',
          style: pw.TextStyle(fontSize: 7, color: muted),
        ),
        pw.Text(
          '${context.pageNumber} / ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 7),
        ),
      ],
    ),
  );

  pw.Widget table(
    List<String> headers,
    List<List<String>> rows, {
    Map<int, pw.TableColumnWidth>? widths,
  }) => pw.TableHelper.fromTextArray(
    headers: headers,
    data: rows,
    columnWidths: widths,
    headerStyle: pw.TextStyle(font: bold, fontSize: 9, color: PdfColors.white),
    headerDecoration: pw.BoxDecoration(color: green),
    cellStyle: const pw.TextStyle(fontSize: 8.5),
    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 9),
    oddRowDecoration: pw.BoxDecoration(color: cream),
    border: pw.TableBorder.all(color: PdfColors.grey300, width: .5),
    cellAlignments: {
      for (var i = 0; i < headers.length; i++)
        i:
            i == headers.length - 1
                ? pw.Alignment.centerRight
                : pw.Alignment.centerLeft,
    },
  );

  pw.Widget summary(
    List<List<String>> values, {
    String? note,
  }) => pw.Inseparable(
    child: pw.Container(
      margin: const pw.EdgeInsets.only(top: 16),
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: cream,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text('RINGKASAN', style: pw.TextStyle(font: bold, color: green)),
          pw.SizedBox(height: 8),
          for (final value in values)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.Row(
                children: [
                  pw.Expanded(child: pw.Text(value[0])),
                  pw.SizedBox(width: 12),
                  pw.Text(value[1], style: pw.TextStyle(font: bold)),
                ],
              ),
            ),
          if (note != null) ...[
            pw.SizedBox(height: 10),
            pw.Text(
              note,
              style: pw.TextStyle(fontSize: 8, color: muted, lineSpacing: 3),
            ),
          ],
        ],
      ),
    ),
  );

  Future<Uint8List> receipt(CustomerReceipt receipt) async {
    final doc = document('Nota Perona #${receipt.number}');
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(22),
        maxPages: 1000,
        header:
            (_) => header(
              'NOTA ORDER',
              '#${receipt.number} | ${date(receipt.createdAt)} WIB',
            ),
        footer: footer,
        build:
            (_) => [
              pw.Text(
                receipt.customer,
                style: pw.TextStyle(font: bold, fontSize: 14),
              ),
              if (receipt.phone.isNotEmpty)
                pw.Text('WhatsApp: ${receipt.phone}'),
              pw.SizedBox(height: 16),
              table(
                ['Layanan', 'Jumlah', 'Harga/unit', 'Subtotal'],
                [
                  for (final line in receipt.lines)
                    [
                      line.service,
                      '${line.quantity}',
                      rupiah(line.price),
                      rupiah(line.price * line.quantity),
                    ],
                ],
                widths: {
                  0: const pw.FlexColumnWidth(2.8),
                  1: const pw.FlexColumnWidth(1.2),
                  2: const pw.FlexColumnWidth(1.4),
                  3: const pw.FlexColumnWidth(1.6),
                },
              ),
              summary([
                ['Nilai layanan', rupiah(receipt.total + receipt.discount)],
                ['Diskon', rupiah(receipt.discount)],
                ['Total tagihan', rupiah(receipt.total)],
                ['Sudah dibayar', rupiah(receipt.paid)],
                ['Sisa tagihan', rupiah(receipt.remaining)],
                ['Status', receipt.remaining == 0 ? 'LUNAS' : 'BELUM LUNAS'],
              ]),
              pw.SizedBox(height: 12),
              pw.Text(
                'Metode pembayaran: ${receipt.methods.isEmpty ? 'Belum ada pembayaran' : receipt.methods.join(' / ')}',
              ),
              pw.SizedBox(height: 18),
              pw.Text(
                'Terima kasih telah mempercayakan perawatan barang kepada Perona Sepatu.',
                style: pw.TextStyle(color: green, lineSpacing: 3),
              ),
            ],
      ),
    );
    return doc.save();
  }

  Future<Uint8List> worker(
    WorkerReport report,
    String name,
    Period period,
  ) async {
    final doc = document('Ongkos $name - ${periodLabel(period)}');
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        maxPages: 1000,
        header:
            (_) => header(
              'RINCIAN ONGKOS',
              '$name | ${periodLabel(period)}',
              internal: true,
            ),
        footer: footer,
        build:
            (_) => [
              pw.Text(
                'Per layanan milik $name; ongkos diakui menurut tanggal order masuk.',
              ),
              pw.SizedBox(height: 14),
              if (report.entries.isEmpty)
                pw.Text('Belum ada layanan pada periode ini.')
              else
                table(
                  [
                    'Tanggal',
                    'Nama customer',
                    'Service layanan',
                    'Jumlah',
                    'Total ongkos',
                  ],
                  [
                    for (final entry in report.entries)
                      [
                        '${date(entry.order['created_at'])}\n#${entry.order['number']}',
                        entry.order['customer_name'] as String,
                        '${entry.item['name']}\n${entry.status}',
                        '${entry.quantity}',
                        rupiah(entry.wage),
                      ],
                  ],
                  widths: {
                    0: const pw.FlexColumnWidth(1.2),
                    1: const pw.FlexColumnWidth(1.8),
                    2: const pw.FlexColumnWidth(2.6),
                    3: const pw.FlexColumnWidth(.7),
                    4: const pw.FlexColumnWidth(1.5),
                  },
                ),
              summary(
                [
                  ['Jumlah order', '${report.orderCount}'],
                  ['Unit / pasang layanan', '${report.quantity}'],
                  ['Unit selesai / diambil', '${report.completed}'],
                  ['Total hak upah tercatat', rupiah(report.total)],
                ],
                note:
                    'Hak upah dicatat saat order masuk, termasuk layanan yang masih Masuk atau Dikerjakan. Total ini belum menunjukkan gaji yang telah dibayarkan. Diskon pelanggan tidak mengurangi ongkos.',
              ),
            ],
      ),
    );
    return doc.save();
  }

  Future<Uint8List> orders(
    OrderReport report,
    Period period, {
    String? workerName,
  }) async {
    final doc = document('Rekap order - ${periodLabel(period)}');
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        maxPages: 1000,
        header:
            (_) => header(
              'REKAP ORDER',
              '${periodLabel(period)}${workerName == null ? '' : ' | Pekerjaan $workerName'}',
              internal: report.includeWages,
            ),
        footer: footer,
        build:
            (_) => [
              pw.Text(
                'Order masuk pada periode terpilih. Angka pembayaran mengikuti kondisi saat PDF dibuat.',
              ),
              if (workerName != null)
                pw.Text(
                  'Tagihan, pembayaran, dan ongkos mencakup seluruh layanan pada order yang memuat pekerjaan $workerName.',
                ),
              pw.SizedBox(height: 14),
              if (report.orders.isEmpty)
                pw.Text('Belum ada order pada periode ini.')
              else
                table(
                  [
                    'Tanggal',
                    'Nama customer',
                    'Service layanan',
                    if (report.includeWages) 'Ongkos kerja',
                    'Tagihan / sisa',
                  ],
                  [
                    for (final order in report.orders)
                      for (var i = 0; i < (order['items'] as List).length; i++)
                        [
                          '${date(order['created_at'])}\n#${order['number']}',
                          order['customer_name'] as String,
                          '${order['items'][i]['name']} x ${order['items'][i]['quantity']}\n${order['items'][i]['status']}',
                          if (report.includeWages)
                            rupiah(
                              money(order['items'][i]['labor_fee']) *
                                  money(order['items'][i]['quantity']),
                            ),
                          i == 0
                              ? '${rupiah(money(order['total']))}\nSisa ${rupiah(orderRemaining(order))}\n${orderRemaining(order) == 0 ? 'Lunas' : 'Belum lunas'}'
                              : '',
                        ],
                  ],
                  widths: {
                    0: const pw.FlexColumnWidth(1.2),
                    1: const pw.FlexColumnWidth(1.7),
                    2: const pw.FlexColumnWidth(2.8),
                    if (report.includeWages) 3: const pw.FlexColumnWidth(1.3),
                    report.includeWages ? 4 : 3: const pw.FlexColumnWidth(1.6),
                  },
                ),
              summary(
                [
                  [
                    'Jumlah order / unit layanan',
                    '${report.orders.length} / ${report.quantity}',
                  ],
                  ['Nilai order setelah diskon', rupiah(report.revenue)],
                  ['Total diskon', rupiah(report.discount)],
                  ['Pembayaran untuk order di laporan', rupiah(report.paid)],
                  ['Sisa tagihan order di laporan', rupiah(report.remaining)],
                  ['Order belum lunas', '${report.unpaidCount}'],
                  ['Customer belum lunas', '${report.unpaidCustomers}'],
                  if (report.includeWages) ...[
                    ['Total gaji / hak upah tercatat', rupiah(report.labor)],
                    [
                      'Nilai order setelah ongkos',
                      rupiah(report.revenue - report.labor),
                    ],
                  ],
                ],
                note:
                    'Satu baris per layanan; tagihan order ditulis sekali pada layanan pertama. Pembayaran yang dikoreksi dan order yang dihapus tidak dihitung. Jumlah customer dihitung dari nomor WhatsApp, atau nama jika nomor kosong. Piutang hanya untuk order dalam laporan ini.${report.includeWages ? ' Hak upah belum menunjukkan gaji dibayarkan; sisa nilai belum dikurangi bahan, sewa, listrik, dan biaya lain.' : ''}',
              ),
            ],
      ),
    );
    return doc.save();
  }
}

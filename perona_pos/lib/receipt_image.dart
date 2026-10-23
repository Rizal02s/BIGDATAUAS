import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'app_theme.dart';
import 'domain.dart';
import 'report_data.dart';

/// A separate, customer-only projection prevents internal wages and notes from
/// entering a shared image. Long receipts continue in additional PNGs.
Future<List<Uint8List>> renderReceiptImages(CustomerReceipt receipt) async {
  await _loadFonts();
  final asset = await rootBundle.load('assets/perona-logo.png');
  final codec = await ui.instantiateImageCodec(asset.buffer.asUint8List());
  final logo = (await codec.getNextFrame()).image;
  codec.dispose();
  final painter = _ReceiptPainter(receipt, logo);
  try {
    return await painter.render();
  } finally {
    painter.dispose();
    logo.dispose();
  }
}

Future<void>? _fonts;
Future<void> _loadFonts() =>
    _fonts ??= () async {
      try {
        for (final entry
            in {
              'ReceiptRegular': 'assets/fonts/Roboto-Regular.ttf',
              'ReceiptBold': 'assets/fonts/Roboto-Bold.ttf',
            }.entries) {
          await (FontLoader(entry.key)
            ..addFont(rootBundle.load(entry.value))).load();
        }
      } catch (_) {
        _fonts = null;
        rethrow;
      }
    }();

class _ReceiptPainter {
  static const width = 540.0, margin = 32.0, contentWidth = width - margin * 2;
  static const maxHeight = 2400.0;
  final CustomerReceipt receipt;
  final ui.Image logo;
  final pages = <({ui.Picture picture, int height})>[];
  final currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );
  late ui.PictureRecorder recorder;
  late ui.Canvas canvas;
  double y = 0;

  _ReceiptPainter(this.receipt, this.logo);

  TextPainter text(
    String value,
    double width, {
    bool bold = false,
    double size = 18,
    Color color = PeronaColors.ink,
    TextAlign align = TextAlign.left,
  }) => TextPainter(
    text: TextSpan(
      text: value,
      style: TextStyle(
        fontFamily: bold ? 'ReceiptBold' : 'ReceiptRegular',
        fontSize: size,
        color: color,
        height: 1.4,
      ),
    ),
    textDirection: ui.TextDirection.ltr,
    textAlign: align,
  )..layout(minWidth: width, maxWidth: width);

  void paragraph(
    String value, {
    bool bold = false,
    double size = 18,
    Color color = PeronaColors.ink,
  }) {
    final p = text(value, contentWidth, bold: bold, size: size, color: color);
    p.paint(canvas, Offset(margin, y));
    y += p.height;
    p.dispose();
  }

  void beginPage() {
    recorder = ui.PictureRecorder();
    canvas = ui.Canvas(recorder);
    canvas.drawColor(const Color(0xffffffff), ui.BlendMode.src);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, width, 8),
      Paint()..color = PeronaColors.brandGreen,
    );
    y = 32;
    final logoHeight = 240 * logo.height / logo.width;
    canvas.drawImageRect(
      logo,
      Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
      Rect.fromLTWH(margin, y, 240, logoHeight),
      Paint(),
    );
    y += logoHeight + 24;
    paragraph(
      'NOTA ORDER #${receipt.number}',
      bold: true,
      size: 25,
      color: PeronaColors.forest,
    );
    y += 8;
    paragraph(
      'Tanggal masuk sepatu: ${DateFormat('dd/MM/yyyy HH:mm').format(jakarta(receipt.createdAt))} WIB',
      size: 18,
    );
    y += 4;
    paragraph(
      'Estimasi selesai: ${receipt.dueDate == null ? 'Belum ditentukan' : '${DateFormat('dd/MM/yyyy').format(receipt.dueDate!)} (WIB)'}',
      size: 18,
      bold: true,
      color: PeronaColors.forest,
    );
    y += 4;
    paragraph(
      'Bagian ${pages.length + 1}',
      size: 15,
      color: PeronaColors.muted,
    );
    y += 20;
    paragraph(receipt.customer, bold: true, size: 22);
    if (receipt.phone.isNotEmpty) {
      paragraph('WhatsApp: ${receipt.phone}', size: 16);
    }
    divider();
  }

  void finishPage() {
    final height = (y + margin).ceil();
    pages.add((picture: recorder.endRecording(), height: height));
  }

  void ensureSpace(double height) {
    if (y + height + margin > maxHeight) {
      finishPage();
      beginPage();
    }
    if (y + height + margin > maxHeight) {
      throw const FormatException('Teks pada nota terlalu panjang.');
    }
  }

  void divider() {
    y += 14;
    canvas.drawLine(
      Offset(margin, y),
      Offset(width - margin, y),
      Paint()
        ..color = PeronaColors.border
        ..strokeWidth = 1,
    );
    y += 16;
  }

  void amount(String label, String value, {bool bold = false}) {
    final left = text(label, contentWidth * .52, bold: bold);
    final right = text(
      value,
      contentWidth * .45,
      bold: bold,
      align: TextAlign.right,
    );
    left.paint(canvas, Offset(margin, y));
    right.paint(canvas, Offset(width - margin - contentWidth * .45, y));
    y += math.max(left.height, right.height) + 10;
    left.dispose();
    right.dispose();
  }

  Future<List<Uint8List>> render() async {
    beginPage();
    for (final line in receipt.lines) {
      final title = text(line.service, contentWidth, bold: true, size: 20);
      ensureSpace(title.height + 62);
      title.paint(canvas, Offset(margin, y));
      y += title.height + 4;
      title.dispose();
      amount(
        '${line.quantity} × ${currency.format(line.price)}',
        currency.format(line.quantity * line.price),
      );
      y += 16;
    }
    final methods =
        'Metode pembayaran: ${receipt.methods.isEmpty ? 'Belum ada pembayaran' : receipt.methods.join(' / ')}';
    final methodText = text(methods, contentWidth, size: 16);
    ensureSpace(340 + methodText.height);
    divider();
    amount('Nilai layanan', currency.format(receipt.total + receipt.discount));
    amount('Diskon', currency.format(receipt.discount));
    amount('Total tagihan', currency.format(receipt.total), bold: true);
    amount('Sudah dibayar', currency.format(receipt.paid));
    amount('Sisa tagihan', currency.format(receipt.remaining), bold: true);
    paragraph(
      receipt.remaining == 0 ? 'LUNAS' : 'BELUM LUNAS',
      bold: true,
      color: PeronaColors.forest,
    );
    y += 14;
    methodText.paint(canvas, Offset(margin, y));
    y += methodText.height;
    methodText.dispose();
    divider();
    paragraph(
      'Terima kasih telah mempercayakan perawatan barang kepada Perona Sepatu.',
      size: 16,
      color: PeronaColors.forest,
    );
    finishPage();
    final images = <Uint8List>[];
    for (final page in pages) {
      // 1080 px wide is legible in chat, while each page stays bounded in memory.
      final scaled = ui.PictureRecorder();
      ui.Canvas(scaled)
        ..scale(2)
        ..drawPicture(page.picture);
      final picture = scaled.endRecording();
      final image = await picture.toImage((width * 2).toInt(), page.height * 2);
      picture.dispose();
      try {
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        if (png == null) throw StateError('Gambar nota gagal dibuat.');
        images.add(png.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    }
    return images;
  }

  void dispose() {
    if (recorder.isRecording) recorder.endRecording().dispose();
    for (final page in pages) {
      page.picture.dispose();
    }
  }
}

import 'package:flutter/services.dart';

/// Accept Indonesian local numbers and explicit international numbers. Reject
/// letters/extensions rather than silently sending to a different recipient.
String? whatsappNumber(String raw) {
  final input = raw.trim();
  if (!RegExp(r'^\+?[0-9\s().-]+$').hasMatch(input)) return null;
  var digits = input.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('00')) {
    digits = digits.substring(2);
  } else if (digits.startsWith('0')) {
    digits = '62${digits.substring(1)}';
  } else if (!input.startsWith('+') && digits.startsWith('8')) {
    digits = '62$digits';
  }
  return RegExp(r'^[1-9][0-9]{7,14}$').hasMatch(digits) ? digits : null;
}

String receiptImageName(String number, int page, int count) {
  final safe = number.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '-');
  return 'nota-perona-$safe${count > 1 ? '-bagian-${page + 1}' : ''}.png';
}

class ReceiptShare {
  static const channel = MethodChannel('id.peronasepatu/receipt_share');

  Future<List<String>> availableApps() async =>
      await channel.invokeListMethod<String>('availableApps') ?? [];

  Future<void> share({
    required List<Uint8List> images,
    required String number,
    required String phone,
    required String package,
  }) async {
    final normalized = whatsappNumber(phone);
    if (normalized == null) {
      throw const FormatException('Nomor WhatsApp tidak valid.');
    }
    await channel.invokeMethod<void>('shareImages', {
      'phone': normalized,
      'package': package,
      'caption':
          'Nota Perona Sepatu #$number. Terima kasih sudah mempercayakan perawatan barang kepada kami.',
      'images': [
        for (var i = 0; i < images.length; i++)
          {
            'bytes': images[i],
            'name': receiptImageName(number, i, images.length),
          },
      ],
    });
  }

  /// Explicit fallback when a WhatsApp version ignores the recipient hint on
  /// ACTION_SEND. Opening a chat does not attach or send the downloaded PNG.
  Future<void> openChat(String phone, String package) async {
    final normalized = whatsappNumber(phone);
    if (normalized == null) {
      throw const FormatException('Nomor WhatsApp tidak valid.');
    }
    await channel.invokeMethod<void>('openChat', {
      'phone': normalized,
      'package': package,
    });
  }
}

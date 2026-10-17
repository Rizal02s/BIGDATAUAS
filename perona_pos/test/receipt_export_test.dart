import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perona_pos/receipt_export.dart';
import 'package:perona_pos/receipt_share.dart';
import 'package:perona_pos/report_data.dart';

import 'pdf_test_support.dart';
import 'report_data_test.dart' show sampleOrder;

final png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLttAAAAABJRU5ErkJggg==',
);

Future<void> openExport(
  WidgetTester tester, {
  String phone = '081234567890',
  int pages = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ReceiptExportPage(
        load: () async => CustomerReceipt.fromOrder(sampleOrder(phone: phone)),
        render: (_) async => List<Uint8List>.filled(pages, png),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> press(
  WidgetTester tester,
  String label, {
  bool settle = true,
}) async {
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
}

void receiptTest(
  String name,
  WidgetTesterCallback callback, {
  TargetPlatform platform = TargetPlatform.android,
}) =>
    testWidgets(name, callback, variant: TargetPlatformVariant.only(platform));

void main() {
  final calls = <MethodCall>[];
  var apps = <String>['com.whatsapp'];
  var failShare = false;

  setUp(() {
    calls.clear();
    apps = ['com.whatsapp'];
    failShare = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ReceiptShare.channel, (call) async {
          calls.add(call);
          if (call.method == 'availableApps') return apps;
          if (failShare) throw PlatformException(code: 'whatsapp_unavailable');
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ReceiptShare.channel, null);
  });

  test(
    'normalize Indonesian and international WA destinations without losing digits',
    () {
      for (final input in [
        '0812-3456-7890',
        '+62 812 3456 7890',
        '6281234567890',
        '81234567890',
        '006281234567890',
      ]) {
        expect(whatsappNumber(input), '6281234567890');
      }
      expect(whatsappNumber('+44 (7700) 900123'), '447700900123');
      expect(whatsappNumber('+81 90 1234 5678'), '819012345678');
      for (final input in [
        '',
        'abc081234567890',
        '08123 ext 4',
        '12',
        '++6281234567890',
        '1234567890123456',
      ]) {
        expect(whatsappNumber(input), isNull);
      }
    },
  );

  receiptTest('PNG download supports cancellation and retry without sharing', (
    tester,
  ) async {
    final picker = TestFilePicker();
    FilePickerPlatform.instance = picker;
    await openExport(tester);
    expect(calls, isEmpty);
    picker.cancel = true;
    await press(tester, 'Unduh gambar');
    expect(picker.saved, isEmpty);
    expect(find.textContaining('berhasil disimpan'), findsNothing);
    picker.cancel = false;
    picker.fail = true;
    await press(tester, 'Unduh gambar');
    expect(picker.saved, isEmpty);
    picker.fail = false;
    await press(tester, 'Unduh gambar');
    expect(picker.saved.single, png);
    expect(picker.mime, 'image/png');
    expect(calls, isEmpty);
  });

  receiptTest(
    'share passes PNG and normalized saved customer phone to WhatsApp',
    (tester) async {
      await openExport(tester);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        '081234567890',
      );
      expect(calls, isEmpty);
      await press(tester, 'Bagikan ke WhatsApp');
      final payload = calls.last.arguments as Map;
      expect(calls.last.method, 'shareImages');
      expect(payload['phone'], '6281234567890');
      expect(payload['package'], 'com.whatsapp');
      expect(payload['images'].single['bytes'], png);
      expect(payload['images'].single['name'], 'nota-perona-1.png');
      expect(find.textContaining('berhasil dikirim'), findsNothing);
    },
  );

  receiptTest(
    'blank phone blocks sharing but still allows download and correction',
    (tester) async {
      FilePickerPlatform.instance = TestFilePicker();
      await openExport(tester, phone: '');
      await press(tester, 'Bagikan ke WhatsApp');
      expect(find.textContaining('Isi nomor WA yang valid'), findsOneWidget);
      expect(calls, isEmpty);
      await press(tester, 'Unduh gambar');
      expect(
        (FilePickerPlatform.instance as TestFilePicker).saved,
        hasLength(1),
      );
      await tester.enterText(find.byType(TextFormField), '0857 1234 5678');
      await press(tester, 'Bagikan ke WhatsApp');
      expect(calls.last.arguments['phone'], '6285712345678');
    },
  );

  receiptTest('choose Business explicitly and attach all receipt pages', (
    tester,
  ) async {
    apps = ['com.whatsapp', 'com.whatsapp.w4b'];
    await openExport(tester, pages: 2);
    await press(tester, 'Bagikan ke WhatsApp', settle: false);
    expect(calls.where((c) => c.method == 'shareImages'), isEmpty);
    await tester.tap(find.text('WhatsApp Business'));
    await tester.pumpAndSettle();
    expect(calls.last.arguments['package'], 'com.whatsapp.w4b');
    expect(calls.last.arguments['images'], hasLength(2));
    expect(
      calls.last.arguments['images'][1]['name'],
      'nota-perona-1-bagian-2.png',
    );
  });

  receiptTest('missing WhatsApp or launch failure is recoverable', (
    tester,
  ) async {
    apps = [];
    await openExport(tester);
    await press(tester, 'Bagikan ke WhatsApp');
    expect(calls.where((c) => c.method == 'shareImages'), isEmpty);
    expect(find.textContaining('WhatsApp belum tersedia'), findsOneWidget);
    apps = ['com.whatsapp'];
    failShare = true;
    await press(tester, 'Bagikan ke WhatsApp');
    expect(find.textContaining('WhatsApp belum tersedia'), findsOneWidget);
    failShare = false;
    await press(tester, 'Buka chat pelanggan');
    expect(calls.last.method, 'openChat');
    expect(calls.last.arguments['phone'], '6281234567890');
  });

  receiptTest(
    'multi-part download saves selected part; non-Android supports download',
    (tester) async {
      final picker = TestFilePicker();
      FilePickerPlatform.instance = picker;
      await openExport(tester, pages: 2);
      await tester.ensureVisible(find.byTooltip('Bagian berikutnya'));
      await tester.tap(find.byTooltip('Bagian berikutnya'));
      await tester.pumpAndSettle();
      await press(tester, 'Unduh gambar bagian 2');
      expect(picker.saved.single, png);
      final shareButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Bagikan ke WhatsApp'),
      );
      expect(shareButton.onPressed, isNull);
      expect(calls, isEmpty);
    },
    platform: TargetPlatform.windows,
  );
}

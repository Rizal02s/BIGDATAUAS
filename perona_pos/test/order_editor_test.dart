import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:perona_pos/app_theme.dart';
import 'package:perona_pos/main.dart';
import 'package:perona_pos/domain.dart';

import 'home_page_test.dart' show capture, loadPreviewFonts, previewKey;
import 'order_submission_test.dart' show SubmissionRepository, draft;

class TestImagePicker extends Fake implements ImagePicker {
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async => XFile.fromData(
    File('assets/perona-logo.png').readAsBytesSync(),
    name: 'shoe.png',
    path: 'shoe.png',
    mimeType: 'image/png',
  );
}

Future<void> openEditor(
  WidgetTester tester,
  SubmissionRepository repo, {
  Json? existing,
}) async {
  tester.view.physicalSize = const Size(412, 892);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final services = await repo.services(), staff = await repo.staff();
  await tester.pumpWidget(
    RepaintBoundary(
      key: previewKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: peronaTheme(),
        home: Builder(
          builder:
              (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed:
                        () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (_) => OrderEditor(
                                  repo: repo,
                                  services: services,
                                  staff: staff,
                                  imagePicker: TestImagePicker(),
                                  existing: existing,
                                ),
                          ),
                        ),
                    child: const Text('Buat order pengujian'),
                  ),
                ),
              ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Buat order pengujian'));
  await tester.pumpAndSettle();
}

Future<void> addService(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Tambah layanan'),
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(find.text('Tambah layanan'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Tambah layanan'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Deep Clean'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadPreviewFonts);

  testWidgets(
    'backfill selects a manual date and time before saving an unpaid order',
    (tester) async {
      final repo = SubmissionRepository();
      await openEditor(tester, repo);
      await tester.tap(find.byKey(const ValueKey('order-date-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Switch to input'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).last, '10/03/2026');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Tanggal order: 03/10/2026'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('order-time-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Switch to text input mode'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(fields.evaluate().length - 2), '10');
      await tester.enterText(fields.last, '15');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Jam order: 10:15 WIB'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).first,
        'Customer tanggal 3',
      );
      await capture(tester, 'order-manual-date');
      await addService(tester);
      await tester.scrollUntilVisible(
        find.text('Simpan order'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Simpan order'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simpan order'));
      await tester.pumpAndSettle();
      expect(repo.savedDraft!['created_at'], '2026-10-03T03:15:00.000Z');
      expect(repo.receipts, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'editing an order preserves its old WIB date and exact timestamp',
    (tester) async {
      final repo = SubmissionRepository();
      final existing = draft()..['created_at'] = '2026-10-02T17:05:12.345Z';
      existing['items'] = [
        {
          ...((await repo.services()).first),
          'id': 'item-a',
          'service_id': 'deep',
          'quantity': 1,
          'worker_id': repo.userId,
          'status': 'Masuk',
        },
      ];
      await openEditor(tester, repo, existing: existing);
      expect(find.text('Tanggal order: 03/10/2026'), findsOneWidget);
      expect(find.text('Jam order: 00:05 WIB'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('order-date-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Simpan order'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Simpan order'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simpan order'));
      await tester.pumpAndSettle();
      expect(repo.savedDraft!['created_at'], existing['created_at']);
      expect(repo.receipts, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('new order collects QRIS and a gallery photo before saving', (
    tester,
  ) async {
    final repo = SubmissionRepository();
    await openEditor(tester, repo);
    await tester.enterText(find.byType(TextFormField).first, 'Andi Pratama');
    await capture(tester, 'order-form');
    await addService(tester);
    await tester.scrollUntilVisible(
      find.widgetWithText(ChoiceChip, 'QRIS'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'QRIS'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Galeri'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Galeri'));
    await tester.pumpAndSettle();
    expect(find.text('1 foto akan disimpan bersama order.'), findsOneWidget);
    await capture(tester, 'order-payment-photo');
    await tester.scrollUntilVisible(
      find.text('Simpan order'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Simpan order'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan order'));
    await tester.pumpAndSettle();
    expect(repo.saves, 1);
    expect(repo.receipts.values.single['method'], 'QRIS');
    expect(repo.photoCalls.length, 1);
    expect(find.text('Buat order pengujian'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unpaid choice saves the order without a payment', (
    tester,
  ) async {
    final repo = SubmissionRepository();
    await openEditor(tester, repo);
    await tester.enterText(find.byType(TextFormField).first, 'Sinta Dewi');
    await addService(tester);
    await tester.scrollUntilVisible(
      find.text('Simpan order'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Simpan order'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan order'));
    await tester.pumpAndSettle();
    expect(repo.saves, 1);
    expect(repo.receipts, isEmpty);
    expect(find.text('Buat order pengujian'), findsOneWidget);
  });

  testWidgets('empty customer is rejected even after scrolling off the field', (
    tester,
  ) async {
    final repo = SubmissionRepository();
    await openEditor(tester, repo);
    await addService(tester);
    await tester.scrollUntilVisible(
      find.text('Simpan order'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Simpan order'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan order'));
    await tester.pumpAndSettle();
    expect(repo.saves, 0);
    expect(find.text('Isi nama pelanggan terlebih dahulu.'), findsOneWidget);
  });
}

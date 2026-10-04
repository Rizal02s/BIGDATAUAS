import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:perona_pos/app_theme.dart';
import 'package:perona_pos/main.dart';

import 'home_page_test.dart' show capture, loadPreviewFonts, previewKey;
import 'order_submission_test.dart' show SubmissionRepository;

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

Future<void> openEditor(WidgetTester tester, SubmissionRepository repo) async {
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
  await tester.tap(find.text('Tambah layanan'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Deep Clean'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadPreviewFonts);

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

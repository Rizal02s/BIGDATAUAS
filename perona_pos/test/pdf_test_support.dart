import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printing/printing.dart';
import 'package:printing/src/interface.dart';

void installPdfTestAssets() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (message) async {
        final path = utf8.decode(message!.buffer.asUint8List());
        var file = File(path);
        if (!file.existsSync()) file = File('build/unit_test_assets/$path');
        if (!file.existsSync()) return null;
        return ByteData.sublistView(file.readAsBytesSync());
      });
}

class TestPrinting extends PrintingPlatform {
  final shared = <Uint8List>[];
  @override
  Future<PrintingInfo> info() async =>
      const PrintingInfo(canRaster: false, canPrint: true, canShare: true);
  @override
  Stream<PdfRaster> raster(
    Uint8List document,
    List<int>? pages,
    double dpi,
  ) async* {
    yield PdfRaster(1, 1, Uint8List.fromList([255, 255, 255, 255]));
  }

  @override
  Future<bool> sharePdf(
    Uint8List bytes,
    String filename,
    Rect bounds,
    String? subject,
    String? body,
    List<String>? emails,
  ) async {
    shared.add(bytes);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestFilePicker extends FilePickerPlatform {
  final saved = <Uint8List>[];
  bool cancel = false, fail = false;
  String? mime;
  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    if (fail) throw Exception('Storage unavailable');
    if (cancel) return null;
    mime = mimeType;
    saved.add(bytes);
    return Uri.parse('content://test/$fileName');
  }
}

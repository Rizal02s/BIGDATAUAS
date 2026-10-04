import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import 'app_theme.dart';
import 'pdf_documents.dart';
import 'report_data.dart';
import 'repository.dart';

String pdfFileName(String name) =>
    '${name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '-').replaceAll(RegExp(r'-+'), '-').toLowerCase()}.pdf';

Future<void> openReceipt(
  BuildContext context,
  Repository repo,
  String id,
) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder:
        (_) => PdfExportPage(
          title: 'Nota pelanggan',
          filename: pdfFileName('nota-perona-$id'),
          description:
              'Unduh nota atau bagikan PDF, lalu pilih WhatsApp dan customer tujuan.',
          pageFormat: PdfPageFormat.a5,
          generate: () async {
            final order = await repo.order(id);
            final pdf = await PeronaPdf.load();
            return pdf.receipt(CustomerReceipt.fromOrder(order));
          },
        ),
  ),
);

class PdfExportPage extends StatefulWidget {
  final String title, filename, description;
  final Future<Uint8List> Function() generate;
  final PdfPageFormat pageFormat;
  const PdfExportPage({
    super.key,
    required this.title,
    required this.filename,
    required this.description,
    required this.generate,
    this.pageFormat = PdfPageFormat.a4,
  });
  @override
  State<PdfExportPage> createState() => _PdfExportPageState();
}

class _PdfExportPageState extends State<PdfExportPage> {
  late Future<Uint8List> future;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    future = widget.generate();
  }

  Future<void> action(Future<void> Function() run) async {
    setState(() => busy = true);
    try {
      await run();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'PDF belum berhasil disimpan atau dibagikan. Coba lagi.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: FutureBuilder<Uint8List>(
      future: future,
      builder: (context, result) {
        if (result.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (result.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.description_outlined, size: 44),
                  const SizedBox(height: 12),
                  const Text(
                    'PDF belum bisa dibuat. Order yang sudah disimpan tetap tersimpan.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed:
                        () => setState(() {
                          future = widget.generate();
                        }),
                    child: const Text('Coba buat PDF lagi'),
                  ),
                ],
              ),
            ),
          );
        }
        final bytes = result.data!;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                widget.description,
                style: const TextStyle(color: PeronaColors.muted, height: 1.5),
              ),
            ),
            Expanded(
              child: PdfPreview(
                build: (_) async => bytes,
                initialPageFormat: widget.pageFormat,
                canChangePageFormat: false,
                canChangeOrientation: false,
                canDebug: false,
                useActions: false,
                onError:
                    (_, _) => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'Pratinjau belum tersedia. PDF tetap dapat diunduh atau dibagikan.',
                        ),
                      ),
                    ),
              ),
            ),
            if (busy) const LinearProgressIndicator(),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed:
                          busy
                              ? null
                              : () => action(() async {
                                final saved = await FilePicker.saveFile(
                                  dialogTitle: 'Simpan PDF Perona',
                                  fileName: widget.filename,
                                  type: FileType.custom,
                                  allowedExtensions: ['pdf'],
                                  bytes: bytes,
                                  mimeType: 'application/pdf',
                                );
                                if (saved != null && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'PDF berhasil disimpan di lokasi pilihanmu.',
                                      ),
                                    ),
                                  );
                                }
                              }),
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Unduh PDF'),
                    ),
                    OutlinedButton.icon(
                      onPressed:
                          busy
                              ? null
                              : () => action(() async {
                                await Printing.sharePdf(
                                  bytes: bytes,
                                  filename: widget.filename,
                                );
                              }),
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Bagikan PDF'),
                    ),
                    TextButton.icon(
                      onPressed:
                          busy
                              ? null
                              : () => action(() async {
                                await Printing.layoutPdf(
                                  name: widget.filename,
                                  format: widget.pageFormat,
                                  dynamicLayout: false,
                                  onLayout: (_) async => bytes,
                                );
                              }),
                      icon: const Icon(Icons.print_outlined),
                      label: const Text('Cetak'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

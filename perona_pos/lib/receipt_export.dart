import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';
import 'receipt_image.dart';
import 'receipt_share.dart';
import 'report_data.dart';
import 'repository.dart';

Future<void> openReceipt(BuildContext context, Repository repo, String id) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => ReceiptExportPage(
              load: () async => CustomerReceipt.fromOrder(await repo.order(id)),
            ),
      ),
    );

class ReceiptExportPage extends StatefulWidget {
  final Future<CustomerReceipt> Function() load;
  final Future<List<Uint8List>> Function(CustomerReceipt) render;
  const ReceiptExportPage({
    super.key,
    required this.load,
    this.render = renderReceiptImages,
  });
  @override
  State<ReceiptExportPage> createState() => _ReceiptExportPageState();
}

class _ReceiptExportPageState extends State<ReceiptExportPage> {
  final phone = TextEditingController();
  final phoneForm = GlobalKey<FormState>();
  final share = ReceiptShare();
  late Future<({CustomerReceipt receipt, List<Uint8List> images})> future;
  bool busy = false;
  int page = 0;
  bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    future = generate();
  }

  @override
  void dispose() {
    phone.dispose();
    super.dispose();
  }

  Future<({CustomerReceipt receipt, List<Uint8List> images})> generate() async {
    final receipt = await widget.load();
    final images = await widget.render(receipt);
    if (images.isEmpty) throw StateError('Nota kosong.');
    if (mounted) phone.text = receipt.phone;
    return (receipt: receipt, images: images);
  }

  void notice(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> action(Future<void> Function() run) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await run();
    } on PlatformException catch (error) {
      notice(
        error.code == 'whatsapp_unavailable'
            ? 'WhatsApp belum tersedia. Pasang WhatsApp atau unduh gambar nota dahulu.'
            : 'Nota belum berhasil diproses. Silakan coba lagi.',
      );
    } catch (_) {
      notice('Nota belum berhasil diproses. Silakan coba lagi.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<String?> chooseApp() async {
    final apps = await share.availableApps();
    if (!mounted) return null;
    if (apps.isEmpty) {
      notice(
        'WhatsApp belum tersedia. Pasang WhatsApp atau unduh gambar nota dahulu.',
      );
      return null;
    }
    if (apps.length == 1) return apps.single;
    return showModalBottomSheet<String>(
      context: context,
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Bagikan melalui'),
                ),
                for (final app in apps)
                  ListTile(
                    leading: const Icon(Icons.chat_outlined),
                    title: Text(
                      app == 'com.whatsapp.w4b'
                          ? 'WhatsApp Business'
                          : 'WhatsApp',
                    ),
                    onTap: () => Navigator.pop(context, app),
                  ),
              ],
            ),
          ),
    );
  }

  Future<void> whatsapp(
    Future<void> Function(String app, String phone) run,
  ) async {
    if (!phoneForm.currentState!.validate()) return;
    final destination = phone.text;
    await action(() async {
      final app = await chooseApp();
      if (app != null && mounted) await run(app, destination);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Nota pelanggan')),
    body: FutureBuilder<({CustomerReceipt receipt, List<Uint8List> images})>(
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
                  const Icon(Icons.image_outlined, size: 44),
                  const SizedBox(height: 12),
                  const Text(
                    'Nota belum bisa dibuat. Order yang sudah disimpan tetap tersimpan.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed:
                        () => setState(() {
                          page = 0;
                          future = generate();
                        }),
                    child: const Text('Coba buat nota lagi'),
                  ),
                ],
              ),
            ),
          );
        }
        final data = result.data!;
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Simpan nota sebagai gambar atau bagikan kepada pelanggan.',
                  style: TextStyle(color: PeronaColors.muted),
                ),
                const SizedBox(height: 16),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 540),
                    child: Image.memory(
                      data.images[page],
                      key: ValueKey('receipt-image-$page'),
                      semanticLabel:
                          'Nota ${data.receipt.number}, bagian ${page + 1}',
                    ),
                  ),
                ),
                if (data.images.length > 1)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: 'Bagian sebelumnya',
                        onPressed:
                            busy || page == 0
                                ? null
                                : () => setState(() => page--),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text('Bagian ${page + 1} dari ${data.images.length}'),
                      IconButton(
                        tooltip: 'Bagian berikutnya',
                        onPressed:
                            busy || page == data.images.length - 1
                                ? null
                                : () => setState(() => page++),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                const SizedBox(height: 20),
                Form(
                  key: phoneForm,
                  child: TextFormField(
                    controller: phone,
                    enabled: !busy,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Nomor WhatsApp tujuan',
                      hintText: 'Contoh: 081234567890',
                      helperText:
                          'Terisi dari order; dapat disesuaikan untuk pengiriman ini.',
                    ),
                    validator:
                        (value) =>
                            whatsappNumber(value ?? '') == null
                                ? 'Isi nomor WA yang valid, contoh 081234567890.'
                                : null,
                  ),
                ),
                const SizedBox(height: 12),
                if (busy) const LinearProgressIndicator(),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed:
                      busy
                          ? null
                          : () => action(() async {
                            final saved = await FilePicker.saveFile(
                              dialogTitle: 'Simpan gambar nota Perona',
                              fileName: receiptImageName(
                                data.receipt.number,
                                page,
                                data.images.length,
                              ),
                              type: FileType.custom,
                              allowedExtensions: ['png'],
                              bytes: data.images[page],
                              mimeType: 'image/png',
                            );
                            if (saved != null) {
                              notice(
                                'Gambar nota berhasil disimpan di lokasi pilihanmu.',
                              );
                            }
                          }),
                  icon: const Icon(Icons.download_outlined),
                  label: Text(
                    data.images.length > 1
                        ? 'Unduh gambar bagian ${page + 1}'
                        : 'Unduh gambar',
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed:
                      busy || !isAndroid
                          ? null
                          : () => whatsapp(
                            (app, destination) => share.share(
                              images: data.images,
                              number: data.receipt.number,
                              phone: destination,
                              package: app,
                            ),
                          ),
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Bagikan ke WhatsApp'),
                ),
                const SizedBox(height: 8),
                Text(
                  isAndroid
                      ? 'Periksa penerima di WhatsApp, lalu tekan kirim. Jika diminta memilih kontak, pilih nomor tujuan di atas.${data.images.length > 1 ? ' Semua bagian nota ikut dilampirkan.' : ''}'
                      : 'Berbagi langsung ke WhatsApp tersedia di aplikasi Android. Gambar tetap bisa diunduh.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: PeronaColors.muted,
                    height: 1.5,
                  ),
                ),
                if (isAndroid) ...[
                  TextButton.icon(
                    onPressed:
                        busy
                            ? null
                            : () => whatsapp(
                              (app, destination) =>
                                  share.openChat(destination, app),
                            ),
                    icon: const Icon(Icons.chat_outlined),
                    label: const Text('Buka chat pelanggan'),
                  ),
                  const Text(
                    'Jika kontak belum ditemukan: unduh gambar, buka chat pelanggan, lalu lampirkan gambar dari penyimpanan.',
                    style: TextStyle(
                      fontSize: 12,
                      color: PeronaColors.muted,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    ),
  );
}

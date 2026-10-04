import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'domain.dart';
import 'repository.dart';
import 'app_theme.dart';
import 'order_submission.dart';
import 'report_data.dart';
import 'pdf_documents.dart';
import 'pdf_export.dart';

part 'home_page.dart';
part 'order_editor.dart';
part 'order_day_page.dart';
part 'worker_detail_page.dart';

final rupiah = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp',
  decimalDigits: 0,
);
String rp(dynamic value) => rupiah.format(money(value));
String stamp(dynamic value) => DateFormat(
  'dd/MM/yyyy HH:mm',
).format(jakarta(DateTime.parse(value as String)));
String errorText(Object error) {
  if (error is OrderTotalChanged) {
    return 'Tarif berubah. Tagihan tersimpan ${rp(error.total)}. Buka detail order untuk memeriksa dan mencatat pembayaran yang benar.';
  }
  if (error is PostgrestException) return error.message;
  if (error is AuthException) return error.message;
  if (error is StorageException) return error.message;
  return 'Proses gagal. Periksa koneksi dan coba kembali. ${error is ArgumentError ? error.message : ''}';
}

void message(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_KEY');
  if (url.isEmpty || key.isEmpty || url.contains('YOUR_PROJECT')) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Konfigurasi belum diisi. Ikuti README: buat config.json dan jalankan dengan --dart-define-from-file=config.json.',
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }
  await Supabase.initialize(url: url, publishableKey: key);
  runApp(const PeronaApp());
}

class PeronaApp extends StatelessWidget {
  const PeronaApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Perona Kasir',
    debugShowCheckedModeBanner: false,
    theme: peronaTheme(),
    home: StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder:
          (context, _) =>
              Supabase.instance.client.auth.currentSession == null
                  ? const LoginPage()
                  : AccountGate(
                    key: ValueKey(
                      Supabase.instance.client.auth.currentUser!.id,
                    ),
                  ),
    ),
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  bool signup = false;
  bool busy = false;
  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      final auth = Supabase.instance.client.auth;
      if (signup) {
        await auth.signUp(
          email: email.text.trim(),
          password: password.text,
          data: {'name': name.text.trim()},
        );
        if (mounted) {
          message(
            context,
            'Akun dibuat. Jika diminta, konfirmasi email lalu masuk. Akun pegawai menunggu aktivasi owner.',
          );
        }
      } else {
        await auth.signInWithPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }
    } catch (e) {
      if (mounted) message(context, errorText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset(
                    'assets/perona-logo.png',
                    height: 112,
                    semanticLabel: 'Perona Sepatu',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Kasir • Rekap layanan • Ongkos kerja',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  if (signup) ...[
                    TextFormField(
                      controller: name,
                      decoration: const InputDecoration(
                        labelText: 'Nama pegawai',
                      ),
                      validator: requiredText,
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator:
                        (v) =>
                            v != null && v.contains('@')
                                ? null
                                : 'Isi email yang valid.',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                    validator:
                        (v) =>
                            (v?.length ?? 0) >= 8
                                ? null
                                : 'Minimal 8 karakter.',
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: busy ? null : submit,
                    child: Text(
                      busy
                          ? 'Memproses…'
                          : signup
                          ? 'Daftar akun pegawai'
                          : 'Masuk',
                    ),
                  ),
                  TextButton(
                    onPressed:
                        busy ? null : () => setState(() => signup = !signup),
                    child: Text(
                      signup ? 'Sudah punya akun? Masuk' : 'Daftar akun baru',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

String? requiredText(String? value) =>
    value == null || value.trim().isEmpty ? 'Wajib diisi.' : null;
String? nonNegative(String? value) =>
    int.tryParse(value ?? '') == null || int.parse(value!) < 0
        ? 'Isi angka rupiah, minimal 0.'
        : null;

class AccountGate extends StatefulWidget {
  const AccountGate({super.key});
  @override
  State<AccountGate> createState() => _AccountGateState();
}

class _AccountGateState extends State<AccountGate> {
  late Future<Json> future;
  final repo = Repository(Supabase.instance.client);
  @override
  void initState() {
    super.initState();
    future = repo.profile();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Json>(
    future: future,
    builder: (context, result) {
      if (result.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (result.hasData &&
          [
            'owner',
            'staff',
            'admin',
            'technician',
          ].contains(result.data!['role'])) {
        return HomePage(repo: repo, profile: result.data!);
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Status akun')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                result.hasError
                    ? errorText(result.error!)
                    : result.data?['role'] == 'disabled'
                    ? 'Akun dinonaktifkan. Hubungi owner.'
                    : 'Akun menunggu aktivasi owner. Untuk akun owner pertama, ikuti langkah bootstrap di README.',
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed:
                    () => setState(() {
                      future = repo.profile();
                    }),
                child: const Text('Periksa status'),
              ),
              TextButton(
                onPressed: () => repo.db.auth.signOut(),
                child: const Text('Keluar'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

int paidTotal(Json o) => ((o['payments'] as List?) ?? [])
    .where((p) => p['voided_at'] == null)
    .fold<int>(0, (sum, p) => sum + money(p['amount']));

class ServicePicker extends StatefulWidget {
  final List<Json> services;
  final bool showWages;
  const ServicePicker({
    super.key,
    required this.services,
    this.showWages = true,
  });
  @override
  State<ServicePicker> createState() => _ServicePickerState();
}

class _ServicePickerState extends State<ServicePicker> {
  String query = '';
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Cari layanan',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => query = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: ListView(
              children:
                  widget.services
                      .where(
                        (s) =>
                            s['active'] == true &&
                            (s['labor_fee'] != null ||
                                s['orderable'] == true) &&
                            (s['name'] as String).toLowerCase().contains(query),
                      )
                      .map(
                        (s) => ListTile(
                          title: Text(s['name'] as String),
                          subtitle: Text(
                            widget.showWages
                                ? '${rp(s['price'])} • Ongkos ${rp(s['labor_fee'])}'
                                : rp(s['price']),
                          ),
                          onTap: () => Navigator.pop(context, s),
                        ),
                      )
                      .toList(),
            ),
          ),
        ],
      ),
    ),
  );
}

class OrderDetail extends StatefulWidget {
  final Repository repo;
  final String id;
  final bool owner;
  final List<Json> services, staff;
  const OrderDetail({
    super.key,
    required this.repo,
    required this.id,
    required this.owner,
    required this.services,
    required this.staff,
  });
  @override
  State<OrderDetail> createState() => _OrderDetailState();
}

class _OrderDetailState extends State<OrderDetail> {
  late Future<Json> future;
  final photoFutures = <String, Future<String>>{};
  bool busy = false;
  @override
  void initState() {
    super.initState();
    future = widget.repo.order(widget.id);
  }

  void reload() {
    if (mounted) {
      setState(() {
        photoFutures.clear();
        future = widget.repo.order(widget.id);
      });
    }
  }

  String workerName(String id) =>
      widget.staff.firstWhere(
            (p) => p['id'] == id,
            orElse: () => {'name': 'Pegawai'},
          )['name']
          as String;
  Future<void> photo(ImageSource source) async {
    setState(() => busy = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1400,
        maxHeight: 1400,
        imageQuality: 75,
      );
      if (picked == null) return;
      await widget.repo.uploadPhoto(
        widget.id,
        await picked.readAsBytes(),
        picked.name.split('.').last,
      );
      if (mounted) {
        message(context, 'Foto berhasil disimpan.');
        reload();
      }
    } catch (e) {
      if (mounted) message(context, errorText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> edit(Json o) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder:
            (_) => OrderEditor(
              repo: widget.repo,
              services: widget.services,
              staff: widget.staff,
              existing: o,
            ),
      ),
    );
    if (result != null) reload();
  }

  Future<void> delete(Json o) async {
    final reason = await askReason(
      context,
      'Hapus order dari rekap?',
      'Order dan upah keluar dari rekap. Riwayat tetap disimpan. Hanya untuk koreksi; bukan pencatatan refund.',
    );
    if (reason == null || !mounted) return;
    setState(() => busy = true);
    try {
      await widget.repo.delete(o, reason);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) message(context, errorText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> voidPay(Json pay) async {
    final reason = await askReason(
      context,
      'Koreksi pembayaran?',
      'Gunakan untuk salah input pembayaran. Pengembalian uang sungguhan belum didukung MVP.',
    );
    if (reason == null || !mounted) return;
    setState(() => busy = true);
    try {
      await widget.repo.voidPayment(pay['id'] as String, reason);
      reload();
    } catch (e) {
      if (mounted) message(context, errorText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Detail order'),
      actions: [
        IconButton(
          onPressed: busy ? null : reload,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<Json>(
      future: future,
      builder: (context, result) {
        if (result.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (result.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(errorText(result.error!)),
            ),
          );
        }
        final o = result.data!;
        final paid = paidTotal(o), remaining = money(o['total']) - paid;
        final methods =
            ((o['payments'] as List?) ?? [])
                .where((payment) => payment['voided_at'] == null)
                .map((payment) => payment['method'] as String)
                .toSet();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '#${o['number']} • ${o['customer_name']}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text('${stamp(o['created_at'])} WIB\n${o['phone']}'),
            if ((o['notes'] as String).isNotEmpty)
              Text('Catatan: ${o['notes']}'),
            const SizedBox(height: 16),
            _HeroCard(
              label: 'Tagihan pelanggan',
              value: rp(o['total']),
              description:
                  '${remaining <= 0 ? 'Lunas' : 'Belum lunas'}${methods.isEmpty ? '' : ' · ${methods.join(' / ')}'}',
              icon: Icons.receipt_long_outlined,
              footer: 'Dibayar ${rp(paid)} · Sisa ${rp(remaining)}',
            ),
            const SizedBox(height: 20),
            const _SectionTitle(
              title: 'Rincian layanan',
              subtitle: 'Status dan penanggung jawab setiap layanan',
            ),
            const SizedBox(height: 12),
            ...(o['items'] as List).map(
              (item) => Card(
                child: ListTile(
                  title: Text('${item['name']} × ${item['quantity']}'),
                  subtitle: Text(
                    '${item['status']} • ${workerName(item['worker_id'] as String)}',
                  ),
                  trailing: Text(
                    rp(money(item['price']) * money(item['quantity'])),
                  ),
                ),
              ),
            ),
            const Divider(),
            Text('Diskon: ${rp(o['discount'])}'),
            Text(
              'Total: ${rp(o['total'])}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text('Sudah dibayar: ${rp(paid)}'),
            Text('Sisa tagihan: ${rp(remaining)}'),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed:
                  busy
                      ? null
                      : () => openReceipt(context, widget.repo, widget.id),
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Nota PDF pelanggan'),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: busy ? null : () => edit(o),
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit order'),
                ),
                if (remaining > 0)
                  OutlinedButton.icon(
                    onPressed:
                        busy
                            ? null
                            : () async {
                              await showDialog<bool>(
                                context: context,
                                barrierDismissible: false,
                                builder:
                                    (_) => PaymentDialog(
                                      repo: widget.repo,
                                      orderId: widget.id,
                                      remaining: remaining,
                                    ),
                              );
                              reload();
                            },
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Tambah pembayaran'),
                  ),
                if (widget.owner)
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => delete(o),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Hapus order'),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Riwayat pembayaran',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            ...((o['payments'] as List?) ?? []).map(
              (p) => ListTile(
                title: Text(
                  '${rp(p['amount'])} • ${p['method']}${p['voided_at'] != null ? ' • Dikoreksi' : ''}',
                ),
                subtitle: Text(
                  '${stamp(p['paid_at'])} WIB${p['void_reason'] == null ? '' : '\n${p['void_reason']}'}',
                ),
                trailing:
                    widget.owner && p['voided_at'] == null
                        ? IconButton(
                          onPressed:
                              busy ? null : () => voidPay(Json.from(p as Map)),
                          icon: const Icon(Icons.undo),
                          tooltip: 'Koreksi salah input',
                        )
                        : null,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Foto barang',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const Text('Foto tersimpan privat. Maksimal 2 MB per foto.'),
            if (((o['order_photos'] as List?) ?? []).isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Belum ada foto barang. Tambahkan dari kamera atau galeri.',
                ),
              ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: busy ? null : () => photo(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Kamera'),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => photo(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Galeri'),
                ),
              ],
            ),
            if (busy) const LinearProgressIndicator(),
            ...((o['order_photos'] as List?) ?? []).map(
              (p) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: FutureBuilder<String>(
                  future: photoFutures.putIfAbsent(
                    p['path'] as String,
                    () => widget.repo.photoUrl(p['path'] as String),
                  ),
                  builder:
                      (_, photo) =>
                          photo.hasData
                              ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  photo.data!,
                                  height: 240,
                                  fit: BoxFit.contain,
                                  errorBuilder:
                                      (_, _, _) => const Text(
                                        'Foto gagal dimuat. Buka ulang detail untuk memperbarui akses.',
                                      ),
                                ),
                              )
                              : photo.hasError
                              ? const Text('Foto gagal dimuat.')
                              : const SizedBox(
                                height: 80,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

Future<String?> askReason(
  BuildContext context,
  String title,
  String description,
) async {
  final controller = TextEditingController();
  final form = GlobalKey<FormState>();
  final result = await showDialog<String>(
    context: context,
    builder:
        (ctx) => AlertDialog(
          title: Text(title),
          content: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(description),
                const SizedBox(height: 12),
                TextFormField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Alasan koreksi',
                  ),
                  validator:
                      (v) =>
                          (v?.trim().length ?? 0) >= 5
                              ? null
                              : 'Minimal 5 karakter.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                if (form.currentState!.validate()) {
                  Navigator.pop(ctx, controller.text.trim());
                }
              },
              child: const Text('Konfirmasi'),
            ),
          ],
        ),
  );
  // Disposal dijadwalkan setelah animasi dialog agar controller tidak dipakai saat transisi.
  Future<void>.delayed(const Duration(seconds: 1), controller.dispose);
  return result;
}

class PaymentDialog extends StatefulWidget {
  final Repository repo;
  final String orderId;
  final int remaining;
  const PaymentDialog({
    super.key,
    required this.repo,
    required this.orderId,
    required this.remaining,
  });
  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  final form = GlobalKey<FormState>();
  final amount = TextEditingController();
  final id = const Uuid().v4();
  String method = 'Tunai';
  bool busy = false;
  @override
  void initState() {
    super.initState();
    amount.text = '${widget.remaining}';
  }

  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await widget.repo.pay(id, widget.orderId, int.parse(amount.text), method);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) message(context, errorText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: const Text('Tambah pembayaran'),
      content: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Sisa tagihan ${rp(widget.remaining)}'),
            const SizedBox(height: 12),
            TextFormField(
              controller: amount,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Nominal (rupiah)'),
              validator: (v) {
                final n = int.tryParse(v ?? '') ?? 0;
                return n > 0 && n <= widget.remaining
                    ? null
                    : 'Nominal harus 1 sampai ${widget.remaining}.';
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: method,
              decoration: const InputDecoration(labelText: 'Metode'),
              items:
                  ['Tunai', 'Transfer', 'QRIS']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
              onChanged: busy ? null : (v) => setState(() => method = v!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: busy ? null : save,
          child: Text(busy ? 'Menyimpan…' : 'Simpan'),
        ),
      ],
    ),
  );
}

class ServiceEditor extends StatefulWidget {
  final Repository repo;
  final Json? existing;
  const ServiceEditor({super.key, required this.repo, this.existing});
  @override
  State<ServiceEditor> createState() => _ServiceEditorState();
}

class _ServiceEditorState extends State<ServiceEditor> {
  final form = GlobalKey<FormState>();
  late TextEditingController name, category, price, fee;
  late String id;
  bool active = true, busy = false;
  @override
  void initState() {
    super.initState();
    final s = widget.existing ?? {};
    id = s['id'] as String? ?? const Uuid().v4();
    name = TextEditingController(text: s['name'] as String? ?? '');
    category = TextEditingController(
      text: s['category'] as String? ?? 'Lainnya',
    );
    price = TextEditingController(text: '${s['price'] ?? 0}');
    fee = TextEditingController(text: '${s['labor_fee'] ?? 0}');
    active = s['active'] as bool? ?? true;
  }

  @override
  void dispose() {
    name.dispose();
    category.dispose();
    price.dispose();
    fee.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await widget.repo.saveService({
        'id': id,
        'name': name.text,
        'category': category.text,
        'price': int.parse(price.text),
        'labor_fee': int.parse(fee.text),
        'active': active,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) message(context, errorText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.existing == null ? 'Tambah layanan' : 'Edit layanan'),
    ),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: name,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Nama layanan'),
            validator: requiredText,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: category,
            decoration: const InputDecoration(labelText: 'Kategori'),
            validator: requiredText,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: price,
            decoration: const InputDecoration(
              labelText: 'Harga pelanggan (rupiah)',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: nonNegative,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: fee,
            decoration: const InputDecoration(
              labelText: 'Ongkos kerja per unit (rupiah)',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: nonNegative,
          ),
          SwitchListTile(
            title: const Text('Layanan aktif'),
            subtitle: const Text(
              'Nonaktifkan untuk menyembunyikan dari input baru.',
            ),
            value: active,
            onChanged: busy ? null : (v) => setState(() => active = v),
          ),
          const Text(
            'Perubahan ini berlaku untuk item baru. Tarif transaksi lama tetap tersimpan.',
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: busy ? null : save,
            child: Text(busy ? 'Menyimpan…' : 'Simpan layanan'),
          ),
        ],
      ),
    ),
  );
}

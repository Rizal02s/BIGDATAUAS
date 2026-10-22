part of 'main.dart';

String _cashDifference(int difference) =>
    difference == 0
        ? 'Sesuai'
        : '${difference < 0 ? 'Kurang' : 'Lebih'} ${rp(difference.abs())}';

class CashPage extends StatefulWidget {
  final Repository repo;
  final List<Json> services, staff;
  const CashPage({
    super.key,
    required this.repo,
    required this.services,
    required this.staff,
  });
  @override
  State<CashPage> createState() => _CashPageState();
}

class _CashPageState extends State<CashPage> {
  DateTime date = jakarta(DateTime.now());
  late Future<CashDay> future;
  String? method;
  int visible = 30;

  @override
  void initState() {
    super.initState();
    future = widget.repo.cashDay(date);
  }

  Future<void> refresh() async {
    final next = widget.repo.cashDay(date);
    setState(() {
      future = next;
    });
    try {
      await next;
    } catch (_) {
      /* FutureBuilder displays the error. */
    }
  }

  Future<void> chooseDate() async {
    final today = jakarta(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(date.year, date.month, date.day),
      firstDate: DateTime(2020),
      lastDate: DateTime(today.year, today.month, today.day),
      currentDate: today,
      helpText: 'Pilih tanggal kas',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );
    if (picked == null || !mounted) return;
    date = picked;
    method = null;
    visible = 30;
    await refresh();
  }

  Future<void> close(CashDay day) async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CashClosingDialog(repo: widget.repo, day: day),
    );
    if (mounted) await refresh();
  }

  Future<void> order(String id) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => OrderDetail(
              repo: widget.repo,
              id: id,
              owner: widget.repo.accessRole == 'owner',
              services: widget.services,
              staff: widget.staff,
            ),
      ),
    );
    if (mounted) await refresh();
  }

  Widget amount(String label, int value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 12,
      runSpacing: 4,
      children: [
        Text(label),
        Text(rp(value), style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );

  Widget closing(CashDay day) {
    final saved = day.closing;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Pencocokan uang tunai',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          if (saved == null) ...[
            const Text(
              'Belum ada tutup kas untuk tanggal ini.',
              style: TextStyle(color: PeronaColors.muted),
            ),
          ] else ...[
            Align(
              alignment: Alignment.centerLeft,
              child: _Badge(
                label:
                    day.changedSinceClosing
                        ? 'Perlu periksa ulang'
                        : 'Tutup kas tersimpan',
                warning: day.changedSinceClosing,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${saved['operator_name'] ?? 'Petugas'} · ${stamp(saved['created_at'])} WIB',
              style: const TextStyle(fontSize: 12, color: PeronaColors.muted),
            ),
            const SizedBox(height: 8),
            amount('Saldo awal', money(saved['opening_cash'])),
            amount(
              'Tunai diterima saat penutupan',
              money(saved['cash_received']),
            ),
            amount('Tunai keluar / disetor', money(saved['cash_out'])),
            const Divider(),
            amount('Tunai seharusnya', money(saved['expected_cash'])),
            amount('Tunai dihitung', money(saved['counted_cash'])),
            Text(
              _cashDifference(money(saved['difference'])),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if ((saved['notes'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Catatan: ${saved['notes']}'),
            ],
            if (day.changedSinceClosing) ...[
              const SizedBox(height: 12),
              const Text(
                'Data pembayaran atau nota berubah setelah tutup kas. Angka di atas adalah catatan saat penutupan; periksa ulang penerimaan terbaru.',
                style: TextStyle(color: PeronaColors.muted, fontSize: 12),
              ),
            ],
          ],
          const SizedBox(height: 16),
          if (saved == null || widget.repo.accessRole == 'owner')
            FilledButton.icon(
              key: const ValueKey('close-daily-cash'),
              onPressed: () => close(day),
              icon: const Icon(Icons.fact_check_outlined),
              label: Text(saved == null ? 'Tutup kas' : 'Perbarui tutup kas'),
            )
          else
            const Text(
              'Pembaruan tutup kas dilakukan oleh owner.',
              style: TextStyle(fontSize: 12, color: PeronaColors.muted),
            ),
        ],
      ),
    );
  }

  Widget payment(Json p) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Card(
      key: ValueKey('cash-payment-${p['id']}'),
      child: InkWell(
        onTap: () => order(p['order_id'] as String),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${p['customer_name']}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text('Nota #${p['order_number']} · ${p['method']}'),
                  Text(
                    rp(p['amount']),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: PeronaColors.forest,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Diterima ${stamp(p['paid_at'])} WIB',
                style: const TextStyle(fontSize: 12, color: PeronaColors.muted),
              ),
              Text(
                'Nota masuk ${DateFormat('dd/MM/yyyy').format(jakarta(DateTime.parse(p['order_at'] as String)))}',
                style: const TextStyle(fontSize: 12, color: PeronaColors.muted),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Kas harian'),
      actions: [
        IconButton(
          onPressed: refresh,
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Muat ulang',
        ),
      ],
    ),
    body: FutureBuilder<CashDay>(
      future: future,
      builder: (context, result) {
        if (result.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (result.hasError) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _EmptyState(
                icon: Icons.wifi_off_rounded,
                title: 'Kas harian belum bisa dimuat',
                description: errorText(result.error!),
                action: FilledButton(
                  onPressed: refresh,
                  child: const Text('Coba lagi'),
                ),
              ),
            ],
          );
        }
        final day = result.data!;
        final payments =
            day.payments
                .where((p) => method == null || p['method'] == method)
                .toList();
        return RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              OutlinedButton.icon(
                key: const ValueKey('cash-date'),
                onPressed: chooseDate,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(
                  '${DateFormat('dd/MM/yyyy').format(day.date)} · WIB',
                ),
              ),
              const SizedBox(height: 16),
              _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Total penerimaan',
                      style: TextStyle(color: PeronaColors.muted),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      rp(day.total),
                      key: const ValueKey('cash-total'),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${day.count} pembayaran',
                      style: const TextStyle(
                        color: PeronaColors.muted,
                        fontSize: 12,
                      ),
                    ),
                    const Divider(),
                    amount('Tunai diterima', day.cash),
                    amount('QRIS diterima', day.qris),
                    if (day.transfer > 0)
                      amount('Transfer diterima', day.transfer),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const _Notice(
                icon: Icons.info_outline,
                text:
                    'Mengikuti tanggal pembayaran diterima, termasuk pelunasan nota lama. QRIS dan transfer tidak masuk perhitungan uang di laci.',
              ),
              const SizedBox(height: 16),
              closing(day),
              const SizedBox(height: 24),
              const _SectionTitle(
                title: 'Pembayaran masuk',
                subtitle: 'Ketuk pembayaran untuk melihat nota asal.',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final value in <String?>[
                    null,
                    'Tunai',
                    'QRIS',
                    if (day.transfer > 0 || method == 'Transfer') 'Transfer',
                  ])
                    ChoiceChip(
                      label: Text(value ?? 'Semua metode'),
                      selected: method == value,
                      onSelected:
                          (_) => setState(() {
                            method = value;
                            visible = 30;
                          }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (payments.isEmpty)
                const _EmptyState(
                  icon: Icons.payments_outlined,
                  title: 'Belum ada pembayaran',
                  description:
                      'Tidak ada penerimaan untuk tanggal dan metode ini.',
                ),
              for (final p in payments.take(visible)) payment(p),
              if (payments.length > visible)
                OutlinedButton(
                  key: const ValueKey('cash-more-payments'),
                  onPressed: () => setState(() => visible += 30),
                  child: Text(
                    'Tampilkan lagi (${payments.length - visible} pembayaran)',
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}

class _CashClosingDialog extends StatefulWidget {
  final Repository repo;
  final CashDay day;
  const _CashClosingDialog({required this.repo, required this.day});
  @override
  State<_CashClosingDialog> createState() => _CashClosingDialogState();
}

class _CashClosingDialogState extends State<_CashClosingDialog> {
  final form = GlobalKey<FormState>();
  final id = const Uuid().v4();
  late final TextEditingController opening, cashOut;
  final counted = TextEditingController(), notes = TextEditingController();
  Json? submitted;
  bool busy = false;
  String? failure;

  @override
  void initState() {
    super.initState();
    opening = TextEditingController(
      text: '${money(widget.day.closing?['opening_cash'])}',
    );
    cashOut = TextEditingController(
      text: '${money(widget.day.closing?['cash_out'])}',
    );
  }

  @override
  void dispose() {
    opening.dispose();
    cashOut.dispose();
    counted.dispose();
    notes.dispose();
    super.dispose();
  }

  CashCount get count => CashCount(
    opening: int.tryParse(opening.text) ?? 0,
    received: widget.day.cash,
    cashOut: int.tryParse(cashOut.text) ?? 0,
    counted: int.tryParse(counted.text) ?? 0,
  );

  String? validateMoney(String? value) {
    final amount = int.tryParse(value ?? '');
    return amount == null || amount < 0 || amount > 1000000000000
        ? 'Isi rupiah 0 sampai 1.000.000.000.000.'
        : null;
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    submitted ??= {
      'opening': count.opening,
      'out': count.cashOut,
      'counted': count.counted,
      'notes': notes.text.trim(),
    };
    setState(() {
      busy = true;
      failure = null;
    });
    try {
      await widget.repo.closeCash(
        id: id,
        day: widget.day,
        opening: submitted!['opening'] as int,
        cashOut: submitted!['out'] as int,
        counted: submitted!['counted'] as int,
        notes: submitted!['notes'] as String,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => failure = errorText(error));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget field(
    String label,
    String key,
    TextEditingController controller, {
    String? helper,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      key: ValueKey(key),
      controller: controller,
      enabled: !busy && submitted == null,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        helperMaxLines: 3,
        errorMaxLines: 3,
      ),
      validator: validator ?? validateMoney,
      onChanged: (_) => setState(() {}),
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: Text(
        widget.day.closing == null ? 'Tutup kas' : 'Perbarui tutup kas',
      ),
      scrollable: true,
      content: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${DateFormat('dd/MM/yyyy').format(widget.day.date)} · WIB'),
            const SizedBox(height: 8),
            Text('Penerimaan tunai ${rp(widget.day.cash)}'),
            const SizedBox(height: 16),
            field(
              'Saldo awal tunai',
              'cash-opening',
              opening,
              helper: 'Uang di laci sebelum penerimaan hari ini.',
            ),
            field(
              'Tunai keluar / disetor',
              'cash-out',
              cashOut,
              helper: 'Total uang yang dikeluarkan dari laci hari ini.',
              validator: (value) {
                final error = validateMoney(value);
                if (error != null) return error;
                return count.cashOut > count.opening + count.received
                    ? 'Melebihi kas yang tersedia.'
                    : null;
              },
            ),
            Text(
              'Tunai seharusnya ${rp(count.expected)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            field(
              'Uang tunai yang dihitung',
              'cash-counted',
              counted,
              helper: 'Hitung uang fisik yang benar-benar ada di laci.',
            ),
            if (counted.text.isNotEmpty)
              Text(
                _cashDifference(count.difference),
                key: const ValueKey('cash-difference'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            const SizedBox(height: 14),
            TextFormField(
              key: const ValueKey('cash-notes'),
              controller: notes,
              enabled: !busy && submitted == null,
              maxLength: 500,
              maxLines: 3,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: const InputDecoration(
                labelText: 'Catatan',
                errorMaxLines: 3,
              ),
              validator:
                  (value) =>
                      (count.difference != 0 || widget.day.closing != null) &&
                              (value?.trim().length ?? 0) < 5
                          ? 'Isi minimal 5 karakter untuk selisih atau pembaruan.'
                          : null,
            ),
            const Text(
              'Tutup kas menyimpan hasil pencocokan. Pembayaran berikutnya tetap dapat dicatat dan akan ditandai untuk diperiksa ulang.',
              style: TextStyle(fontSize: 12, color: PeronaColors.muted),
            ),
            if (failure != null) ...[
              const SizedBox(height: 12),
              Text(
                failure!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        if (failure != null)
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context, false),
            child: const Text('Muat ulang laporan'),
          ),
        FilledButton(
          key: const ValueKey('save-cash-closing'),
          onPressed: busy ? null : save,
          child: Text(
            busy
                ? 'Menyimpan…'
                : failure != null
                ? 'Coba simpan lagi'
                : 'Simpan tutup kas',
          ),
        ),
      ],
    ),
  );
}

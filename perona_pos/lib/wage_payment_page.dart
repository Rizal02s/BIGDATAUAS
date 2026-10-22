part of 'main.dart';

String _wagePeriodLabel(Period period) =>
    '${DateFormat('dd/MM/yyyy').format(jakarta(period.start))} – '
    '${DateFormat('dd/MM/yyyy').format(jakarta(period.end.subtract(const Duration(seconds: 1))))}';

Widget _wageAmount(String label, int value) => Padding(
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

class WagePaymentsPage extends StatefulWidget {
  final Repository repo;
  final Period initialPeriod;
  final List<Json> services, staff;
  const WagePaymentsPage({
    super.key,
    required this.repo,
    required this.initialPeriod,
    required this.services,
    required this.staff,
  });
  @override
  State<WagePaymentsPage> createState() => _WagePaymentsPageState();
}

class _WagePaymentsPageState extends State<WagePaymentsPage> {
  late Period period;
  late Future<List<Json>> future;
  @override
  void initState() {
    super.initState();
    period = widget.initialPeriod;
    future = widget.repo.wageOverview(period);
  }

  Future<void> refresh() async {
    final next = widget.repo.wageOverview(period);
    setState(() {
      future = next;
    });
    try {
      await next;
    } catch (_) {
      /* FutureBuilder shows the error. */
    }
  }

  Future<void> choosePeriod() async {
    final first = jakarta(period.start),
        last = jakarta(period.end.subtract(const Duration(days: 1)));
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100, 12, 31),
      initialDateRange: DateTimeRange(
        start: DateTime(first.year, first.month, first.day),
        end: DateTime(last.year, last.month, last.day),
      ),
      helpText: 'Pilih periode nota ongkos',
      saveText: 'Terapkan',
      confirmText: 'Terapkan',
      cancelText: 'Batal',
      fieldStartLabelText: 'Tanggal awal nota',
      fieldEndLabelText: 'Tanggal akhir nota',
    );
    if (picked == null || !mounted) return;
    period = Period.betweenDates(picked.start, picked.end);
    await refresh();
  }

  Future<void> worker(String id) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => _WageLedgerPage(
              repo: widget.repo,
              workerId: id,
              period: period,
              services: widget.services,
              staff: widget.staff,
            ),
      ),
    );
    if (mounted) await refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Pembayaran ongkos'),
      actions: [
        IconButton(
          onPressed: refresh,
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Muat ulang',
        ),
      ],
    ),
    body: FutureBuilder<List<Json>>(
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
                title: 'Pembayaran ongkos belum bisa dimuat',
                description: errorText(result.error!),
                action: FilledButton(
                  onPressed: refresh,
                  child: const Text('Coba lagi'),
                ),
              ),
            ],
          );
        }
        final rows = result.data!;
        int sum(String field) =>
            rows.fold<int>(0, (s, row) => s + money(row[field]));
        return RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              OutlinedButton.icon(
                key: const ValueKey('wage-payment-period'),
                onPressed: choosePeriod,
                icon: const Icon(Icons.date_range_outlined),
                label: Text('${_wagePeriodLabel(period)} · WIB'),
              ),
              const SizedBox(height: 16),
              _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Ongkos tim',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    _wageAmount('Hak ongkos', sum('earned')),
                    _wageAmount('Sudah dibayar', sum('paid')),
                    _wageAmount('Sisa belum dibayar', sum('remaining')),
                    if (sum('excess') > 0)
                      _wageAmount('Kelebihan perlu diperiksa', sum('excess')),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const _Notice(
                icon: Icons.info_outline,
                text:
                    'Periode mengikuti tanggal masuk nota. Pembayaran tetap terhitung meskipun dibayarkan pada tanggal atau bulan berbeda.',
              ),
              const SizedBox(height: 20),
              if (rows.isEmpty)
                const _EmptyState(
                  icon: Icons.groups_outlined,
                  title: 'Belum ada ongkos pada periode ini',
                  description:
                      'Pilih periode nota lain untuk melihat hak ongkos dan pembayarannya.',
                ),
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: InkWell(
                      key: ValueKey('wage-balance-${row['worker_id']}'),
                      onTap: () => worker(row['worker_id'] as String),
                      borderRadius: BorderRadius.circular(18),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              row['worker_name'] as String,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _wageAmount('Hak ongkos', money(row['earned'])),
                            _wageAmount('Dibayar', money(row['paid'])),
                            _wageAmount('Sisa', money(row['remaining'])),
                            if (money(row['excess']) > 0)
                              _wageAmount('Kelebihan', money(row['excess'])),
                            const SizedBox(height: 8),
                            const Text(
                              'Lihat rincian & riwayat',
                              style: TextStyle(
                                color: PeronaColors.forest,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}

class _WageLedgerPage extends StatefulWidget {
  final Repository repo;
  final String workerId;
  final Period period;
  final List<Json> services, staff;
  const _WageLedgerPage({
    required this.repo,
    required this.workerId,
    required this.period,
    required this.services,
    required this.staff,
  });
  @override
  State<_WageLedgerPage> createState() => _WageLedgerPageState();
}

class _WageLedgerPageState extends State<_WageLedgerPage> {
  late Future<WageLedger> future;
  bool correcting = false;
  int visibleNotes = 20, visibleHistory = 20;
  @override
  void initState() {
    super.initState();
    future = widget.repo.wageLedger(widget.workerId, widget.period);
  }

  Future<void> refresh() async {
    final next = widget.repo.wageLedger(widget.workerId, widget.period);
    setState(() {
      future = next;
    });
    try {
      await next;
    } catch (_) {
      /* FutureBuilder shows the error. */
    }
  }

  Future<void> pay(WageLedger ledger) async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => _WagePaymentDialog(
            repo: widget.repo,
            ledger: ledger,
            period: widget.period,
          ),
    );
    if (mounted) await refresh();
  }

  Future<void> correct(Json payout) async {
    if (correcting || widget.repo.accessRole != 'owner') return;
    final reason = await askReason(
      context,
      'Koreksi pembayaran ongkos',
      'Batalkan pencatatan pembayaran ${rp(payout['amount'])}. Koreksi berlaku untuk seluruh alokasi pembayaran ini, termasuk nota di periode lain.',
    );
    if (reason == null || !mounted) return;
    setState(() => correcting = true);
    try {
      await widget.repo.voidWagePayout(payout['id'] as String, reason);
      if (mounted) await refresh();
    } catch (error) {
      if (mounted) message(context, errorText(error));
    } finally {
      if (mounted) setState(() => correcting = false);
    }
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

  Widget history(Json p) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${stamp(p['paid_at'])} WIB · ${p['method']}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _wageAmount('Untuk nota periode ini', money(p['allocated_amount'])),
          if (money(p['allocated_amount']) != money(p['amount']))
            _wageAmount('Total pembayaran', money(p['amount'])),
          Text(
            'Dicatat oleh ${p['operator_name']}',
            style: const TextStyle(fontSize: 12, color: PeronaColors.muted),
          ),
          for (final a in p['allocations'] as List)
            Text(
              'Nota #${a['order_number']} · ${a['customer_name']} · ${rp(a['amount'])}',
              style: const TextStyle(fontSize: 12),
            ),
          if ((p['notes'] as String? ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Catatan: ${p['notes']}'),
          ],
          if (p['voided_at'] != null) ...[
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: _Badge(label: 'Dikoreksi', warning: true),
            ),
            Text(
              '${p['void_reason']}',
              style: const TextStyle(fontSize: 12, color: PeronaColors.muted),
            ),
          ] else if (widget.repo.accessRole == 'owner')
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: ValueKey('void-wage-${p['id']}'),
                onPressed: correcting ? null : () => correct(p),
                icon: const Icon(Icons.undo_rounded, size: 18),
                label: const Text('Koreksi salah catat'),
              ),
            ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Rincian pembayaran ongkos'),
      actions: [
        IconButton(
          onPressed: refresh,
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Muat ulang',
        ),
      ],
    ),
    body: FutureBuilder<WageLedger>(
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
                title: 'Rincian pembayaran belum bisa dimuat',
                description: errorText(result.error!),
                action: FilledButton(
                  onPressed: refresh,
                  child: const Text('Coba lagi'),
                ),
              ),
            ],
          );
        }
        final ledger = result.data!;
        return RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              _SectionTitle(
                title: ledger.workerName,
                subtitle: '${_wagePeriodLabel(widget.period)} · Nota masuk WIB',
              ),
              const SizedBox(height: 16),
              _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _wageAmount('Hak ongkos', ledger.earned),
                    _wageAmount('Sudah dibayar', ledger.paid),
                    _wageAmount('Sisa belum dibayar', ledger.remaining),
                    if (ledger.excess > 0)
                      _wageAmount('Kelebihan perlu diperiksa', ledger.excess),
                  ],
                ),
              ),
              if (ledger.excess > 0) ...[
                const SizedBox(height: 12),
                const _Notice(
                  icon: Icons.warning_amber_rounded,
                  text:
                      'Ada pembayaran melebihi hak ongkos setelah nota berubah. Periksa rincian dan riwayat; kelebihan tidak otomatis dipindahkan ke nota lain.',
                ),
              ],
              if (widget.repo.accessRole == 'owner') ...[
                const SizedBox(height: 14),
                FilledButton.icon(
                  key: const ValueKey('pay-wages'),
                  onPressed: ledger.remaining > 0 ? () => pay(ledger) : null,
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Catat pembayaran'),
                ),
              ],
              const SizedBox(height: 14),
              const _Notice(
                icon: Icons.info_outline,
                text:
                    'Pembayaran dialokasikan dari nota paling lama yang masih memiliki sisa ongkos. Tanggal bayar terpisah dari tanggal masuk nota.',
              ),
              const SizedBox(height: 24),
              const _SectionTitle(
                title: 'Riwayat pembayaran',
                subtitle: 'Alokasi untuk nota dalam periode terpilih.',
              ),
              const SizedBox(height: 12),
              if (ledger.history.isEmpty)
                const _Panel(child: Text('Belum ada pembayaran ongkos.')),
              for (final p in ledger.history.take(visibleHistory)) history(p),
              if (ledger.history.length > visibleHistory)
                OutlinedButton(
                  onPressed: () => setState(() => visibleHistory += 20),
                  child: const Text('Tampilkan riwayat lainnya'),
                ),
              const SizedBox(height: 20),
              const _SectionTitle(
                title: 'Saldo per nota',
                subtitle: 'Ketuk nota aktif untuk melihat rincian layanan.',
              ),
              const SizedBox(height: 12),
              if (ledger.notes.isEmpty)
                const _Panel(
                  child: Text('Belum ada nota ongkos pada periode ini.'),
                ),
              for (final n in ledger.notes.take(visibleNotes))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: InkWell(
                      key: ValueKey('wage-payment-note-${n['order_id']}'),
                      onTap:
                          n['deleted'] == true
                              ? null
                              : () => order(n['order_id'] as String),
                      borderRadius: BorderRadius.circular(18),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '${n['customer_name']} · Nota #${n['order_number']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              DateFormat('dd/MM/yyyy').format(
                                jakarta(
                                  DateTime.parse(n['order_at'] as String),
                                ),
                              ),
                              style: const TextStyle(
                                fontSize: 12,
                                color: PeronaColors.muted,
                              ),
                            ),
                            if (n['deleted'] == true)
                              const Text(
                                'Nota dihapus',
                                style: TextStyle(color: PeronaColors.muted),
                              ),
                            const SizedBox(height: 8),
                            Text('${n['services']}'),
                            const SizedBox(height: 8),
                            _wageAmount('Hak ongkos', money(n['earned'])),
                            _wageAmount('Dibayar', money(n['paid'])),
                            _wageAmount('Sisa', money(n['remaining'])),
                            if (money(n['excess']) > 0)
                              _wageAmount('Kelebihan', money(n['excess'])),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (ledger.notes.length > visibleNotes)
                OutlinedButton(
                  key: const ValueKey('more-wage-notes'),
                  onPressed: () => setState(() => visibleNotes += 20),
                  child: const Text('Tampilkan nota lainnya'),
                ),
            ],
          ),
        );
      },
    ),
  );
}

class _WagePaymentDialog extends StatefulWidget {
  final Repository repo;
  final WageLedger ledger;
  final Period period;
  const _WagePaymentDialog({
    required this.repo,
    required this.ledger,
    required this.period,
  });
  @override
  State<_WagePaymentDialog> createState() => _WagePaymentDialogState();
}

class _WagePaymentDialogState extends State<_WagePaymentDialog> {
  final form = GlobalKey<FormState>();
  final id = const Uuid().v4();
  late final TextEditingController amount;
  final notes = TextEditingController();
  String method = 'Tunai';
  DateTime? paidAt;
  bool busy = false;
  Json? submitted;
  String? failure;
  @override
  void initState() {
    super.initState();
    amount = TextEditingController(text: '${widget.ledger.remaining}');
  }

  @override
  void dispose() {
    amount.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> chooseTime() async {
    final now = jakarta(DateTime.now()),
        initial = paidAt == null ? jakarta(DateTime.now()) : jakarta(paidAt!);
    final day = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day),
      currentDate: now,
      helpText: 'Tanggal pembayaran ongkos',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
      helpText: 'Jam pembayaran · WIB',
    );
    if (time == null || !mounted) return;
    setState(
      () =>
          paidAt = jakartaToUtc(
            DateTime(day.year, day.month, day.day, time.hour, time.minute),
          ),
    );
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    submitted ??= {
      'amount': int.parse(amount.text),
      'method': method,
      'paid_at': paidAt?.toUtc().toIso8601String(),
      'notes': notes.text.trim(),
    };
    setState(() {
      busy = true;
      failure = null;
    });
    try {
      await widget.repo.payWages(
        id: id,
        ledger: widget.ledger,
        period: widget.period,
        amount: submitted!['amount'] as int,
        method: submitted!['method'] as String,
        paidAt:
            submitted!['paid_at'] == null
                ? null
                : DateTime.parse(submitted!['paid_at'] as String),
        notes: submitted!['notes'] as String,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => failure = errorText(error));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: const Text('Bayar ongkos'),
      scrollable: true,
      content: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.ledger.workerName,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              'Nota ${_wagePeriodLabel(widget.period)}',
              style: const TextStyle(fontSize: 12, color: PeronaColors.muted),
            ),
            const SizedBox(height: 8),
            Text('Sisa ongkos ${rp(widget.ledger.remaining)}'),
            const SizedBox(height: 16),
            TextFormField(
              key: const ValueKey('wage-payment-amount'),
              controller: amount,
              enabled: !busy && submitted == null,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Jumlah dibayarkan',
                errorMaxLines: 3,
              ),
              validator: (value) {
                final n = int.tryParse(value ?? '');
                return n == null ||
                        n <= 0 ||
                        n > widget.ledger.remaining ||
                        n > 1000000000000
                    ? 'Isi nominal lebih dari 0, maksimal ${rp(widget.ledger.remaining)}.'
                    : null;
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: method,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Metode pembayaran'),
              items: [
                for (final m in ['Tunai', 'Transfer', 'QRIS'])
                  DropdownMenuItem(value: m, child: Text(m)),
              ],
              onChanged:
                  busy || submitted != null
                      ? null
                      : (value) => setState(() => method = value!),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const ValueKey('wage-paid-at'),
              onPressed: busy || submitted != null ? null : chooseTime,
              icon: const Icon(Icons.event_outlined),
              label: Text(
                paidAt == null
                    ? 'Waktu bayar: sekarang'
                    : '${stamp(paidAt!.toIso8601String())} WIB',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('wage-payment-notes'),
              controller: notes,
              enabled: !busy && submitted == null,
              maxLength: 500,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
              ),
            ),
            const Text(
              'Untuk pembayaran Tunai, masukkan juga nominalnya dalam total tunai keluar saat tutup kas.',
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
            child: const Text('Muat ulang'),
          ),
        FilledButton(
          key: const ValueKey('save-wage-payment'),
          onPressed: busy ? null : save,
          child: Text(
            busy
                ? 'Menyimpan…'
                : failure != null
                ? 'Coba simpan lagi'
                : 'Simpan pembayaran',
          ),
        ),
      ],
    ),
  );
}

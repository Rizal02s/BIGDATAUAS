part of 'main.dart';

class ExpensesPage extends StatefulWidget {
  final Repository repo;
  const ExpensesPage({super.key, required this.repo});
  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  Period period = Period.forDate(jakarta(DateTime.now()), 'month');
  ExpenseReport? report;
  List<Json> rows = [];
  bool busy = false;
  String? failure;
  int page = 0, request = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool next = false}) async {
    if (widget.repo.accessRole != 'owner') return;
    final token = ++request;
    final target = next ? page + 1 : 0;
    setState(() {
      busy = true;
      failure = null;
      if (!next) {
        rows = [];
        report = null;
      }
    });
    try {
      final result = await widget.repo.expenses(period, target);
      if (!mounted || token != request) return;
      setState(() {
        report = result;
        page = target;
        rows =
            next
                ? {
                  for (final row in [...rows, ...result.rows]) row['id']: row,
                }.values.toList()
                : result.rows;
      });
    } catch (error) {
      if (mounted && token == request) {
        setState(() => failure = errorText(error));
      }
    } finally {
      if (mounted && token == request) setState(() => busy = false);
    }
  }

  Future<void> choosePeriod() async {
    final today = jakarta(DateTime.now());
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(
        start: jakarta(period.start),
        end: jakarta(period.end.subtract(const Duration(days: 1))),
      ),
      firstDate: DateTime(2020),
      lastDate: DateTime(today.year, today.month + 1, 0),
      helpText: 'Periode pengeluaran (WIB)',
      saveText: 'Pilih',
      confirmText: 'Pilih',
      cancelText: 'Batal',
    );
    if (picked == null || !mounted) return;
    period = Period.betweenDates(picked.start, picked.end);
    await load();
  }

  Future<void> add() async {
    final saved = await showDialog<DateTime>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ExpenseDialog(repo: widget.repo),
    );
    if (saved != null && mounted) {
      if (!period.contains(jakartaToUtc(saved))) {
        period = Period.forDate(saved, 'month');
      }
      await load();
      if (mounted) message(context, 'Pengeluaran tersimpan.');
    }
  }

  Future<void> correct(Json expense) async {
    final reason = await askReason(
      context,
      'Koreksi pengeluaran?',
      '${expense['title']} sebesar ${rp(expense['amount'])} akan dikeluarkan dari total. Riwayat tetap disimpan. Gunakan untuk salah catat; setelah itu buat catatan baru yang benar.',
    );
    if (reason == null || !mounted) return;
    setState(() => busy = true);
    try {
      await widget.repo.voidExpense(expense['id'] as String, reason);
      if (mounted) await load();
    } catch (error) {
      if (mounted) message(context, errorText(error));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.repo.accessRole != 'owner') {
      return Scaffold(
        appBar: AppBar(title: const Text('Pengeluaran usaha')),
        body: const Center(child: Text('Pengeluaran usaha hanya untuk owner.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengeluaran usaha'),
        actions: [
          IconButton(
            onPressed: busy ? null : () => load(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => load(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            OutlinedButton.icon(
              key: const ValueKey('expense-period'),
              onPressed: busy ? null : choosePeriod,
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text('${periodLabel(period)} · WIB'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const ValueKey('add-expense'),
              onPressed: busy ? null : add,
              icon: const Icon(Icons.add),
              label: const Text('Catat pengeluaran'),
            ),
            const SizedBox(height: 16),
            if (report != null) ...[
              _HeroCard(
                label: 'Total pengeluaran',
                value: rp(report!.total),
                description:
                    '${report!.count} pengeluaran aktif pada periode ini.',
                icon: Icons.payments_outlined,
                footer: 'Dari kas toko ${rp(report!.drawerCash)}',
              ),
              const SizedBox(height: 12),
              if (report!.categories.isNotEmpty)
                _Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Per kategori',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      for (final category in report!.categories)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              Text(category['category'] as String),
                              Text(rp(category['total'])),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              const Text(
                'Riwayat pengeluaran',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
            ],
            for (final expense in rows)
              _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      expense['title'] as String,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${DateFormat('dd/MM/yyyy').format(DateTime.parse(expense['spent_on'] as String))} · ${expense['category']}',
                    ),
                    const SizedBox(height: 6),
                    Text(
                      rp(expense['amount']),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: PeronaColors.forest,
                      ),
                    ),
                    Text(
                      '${expense['method']}${expense['method'] == 'Tunai'
                          ? expense['from_drawer'] == true
                              ? ' · Dari kas toko'
                              : ' · Di luar kas toko'
                          : ''}',
                    ),
                    Text(
                      'Dicatat oleh ${expense['operator_name'] ?? 'Owner'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: PeronaColors.muted,
                      ),
                    ),
                    if ((expense['notes'] as String? ?? '').isNotEmpty)
                      Text('Catatan: ${expense['notes']}'),
                    if (expense['voided_at'] != null) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Dikoreksi · Tidak dihitung',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text('Alasan: ${expense['void_reason']}'),
                      Text('Oleh ${expense['void_operator_name'] ?? 'Owner'}'),
                    ] else
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          key: ValueKey('correct-expense-${expense['id']}'),
                          onPressed: busy ? null : () => correct(expense),
                          icon: const Icon(Icons.undo, size: 18),
                          label: const Text('Koreksi salah catat'),
                        ),
                      ),
                  ],
                ),
              ),
            if (busy)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (failure != null) ...[
              Text(
                failure!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              TextButton(
                onPressed: () => load(next: rows.isNotEmpty),
                child: const Text('Coba lagi'),
              ),
            ],
            if (!busy && failure == null && rows.isEmpty)
              const _Notice(
                icon: Icons.receipt_long_outlined,
                text: 'Belum ada pengeluaran pada periode ini.',
              ),
            if (!busy &&
                failure == null &&
                report != null &&
                rows.length < report!.historyCount)
              OutlinedButton(
                onPressed: () => load(next: true),
                child: const Text('Muat lebih banyak'),
              ),
            const SizedBox(height: 16),
            const Text(
              'Biaya yang sudah dibayar. Ongkos pegawai dicatat melalui tab Ongkos. Pengambilan pemilik atau setoran ke bank masuk Tunai keluar pada Kas harian jika uangnya keluar dari laci toko.',
              style: TextStyle(color: PeronaColors.muted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseDialog extends StatefulWidget {
  final Repository repo;
  const _ExpenseDialog({required this.repo});
  @override
  State<_ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<_ExpenseDialog> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController(),
      amount = TextEditingController(),
      notes = TextEditingController();
  final id = const Uuid().v4();
  DateTime date = jakarta(DateTime.now());
  String category = expenseCategories.first, method = 'Tunai';
  bool fromDrawer = true, busy = false;
  Json? submitted;
  String? failure;
  bool get editable => !busy && submitted == null;
  @override
  void dispose() {
    title.dispose();
    amount.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> chooseDate() async {
    final today = jakarta(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(date.year, date.month, date.day),
      firstDate: DateTime(2020),
      lastDate: DateTime(today.year, today.month, today.day),
      helpText: 'Tanggal biaya dibayar (WIB)',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );
    if (picked != null && mounted) setState(() => date = picked);
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    submitted ??= {
      'id': id,
      'spent_on': cashDate(date),
      'title': title.text.trim(),
      'category': category,
      'amount': int.parse(amount.text),
      'method': method,
      'from_drawer': method == 'Tunai' && fromDrawer,
      'notes': notes.text.trim(),
    };
    setState(() {
      busy = true;
      failure = null;
    });
    try {
      await widget.repo.recordExpense(submitted!);
      if (mounted) {
        Navigator.pop(
          context,
          DateTime.parse(submitted!['spent_on'] as String),
        );
      }
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
      title: const Text('Catat pengeluaran'),
      scrollable: true,
      content: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('expense-date'),
              onPressed: editable ? chooseDate : null,
              icon: const Icon(Icons.event_outlined),
              label: Text('${DateFormat('dd/MM/yyyy').format(date)} · WIB'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('expense-title'),
              controller: title,
              enabled: editable,
              maxLength: 150,
              decoration: const InputDecoration(
                labelText: 'Keterangan',
                hintText: 'Contoh: Beli cairan pembersih',
              ),
              validator: requiredText,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const ValueKey('expense-category'),
              initialValue: category,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Kategori'),
              items:
                  expenseCategories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
              onChanged: editable ? (v) => setState(() => category = v!) : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('expense-amount'),
              controller: amount,
              enabled: editable,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Nominal (rupiah)',
                errorMaxLines: 3,
              ),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                return n == null || n < 1 || n > 1000000000000
                    ? 'Isi nominal lebih dari 0, maksimal Rp1 triliun.'
                    : null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const ValueKey('expense-method'),
              initialValue: method,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Metode pembayaran'),
              items:
                  ['Tunai', 'Transfer', 'QRIS']
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
              onChanged: editable ? (v) => setState(() => method = v!) : null,
            ),
            if (method == 'Tunai')
              SwitchListTile(
                key: const ValueKey('expense-from-drawer'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Diambil dari kas toko'),
                value: fromDrawer,
                onChanged:
                    editable ? (v) => setState(() => fromDrawer = v) : null,
              ),
            if (method == 'Tunai' && fromDrawer)
              const Text(
                'Masukkan nominal ini satu kali ke total Tunai keluar/disetor saat tutup kas.',
                style: TextStyle(
                  fontSize: 12,
                  color: PeronaColors.muted,
                  height: 1.5,
                ),
              ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('expense-notes'),
              controller: notes,
              enabled: editable,
              maxLength: 500,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
              ),
            ),
            if (failure != null)
              Text(
                failure!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (submitted != null && !busy)
              const Text(
                'Jika respons terputus, coba simpan kembali untuk memeriksa catatan yang sama. Periksa riwayat sebelum membuat catatan baru.',
                style: TextStyle(fontSize: 12, height: 1.5),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
        FilledButton(
          key: const ValueKey('save-expense'),
          onPressed: busy ? null : save,
          child: Text(
            busy
                ? 'Menyimpan…'
                : submitted == null
                ? 'Simpan pengeluaran'
                : 'Coba simpan lagi',
          ),
        ),
      ],
    ),
  );
}

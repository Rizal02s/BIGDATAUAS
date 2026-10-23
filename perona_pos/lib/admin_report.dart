part of 'main.dart';

class _OperationalReportPanel extends StatefulWidget {
  final Repository repo;
  final Period period;
  final int revision;
  final bool compact;
  final Future<void> Function(String) onOrder;
  const _OperationalReportPanel({
    super.key,
    required this.repo,
    required this.period,
    required this.revision,
    this.compact = false,
    required this.onOrder,
  });
  @override
  State<_OperationalReportPanel> createState() =>
      _OperationalReportPanelState();
}

class _OperationalReportPanelState extends State<_OperationalReportPanel> {
  OperationalReport? report;
  List<Json> payments = [];
  String? failure;
  int page = 0, request = 0;
  bool busy = true;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant _OperationalReportPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision ||
        oldWidget.period.start != widget.period.start ||
        oldWidget.period.end != widget.period.end) {
      load();
    }
  }

  Future<void> load({bool next = false}) async {
    final token = ++request, target = next ? page + 1 : 0;
    setState(() {
      busy = true;
      failure = null;
      if (!next) {
        report = null;
        payments = [];
      }
    });
    try {
      final result = await widget.repo.operationalReport(
        widget.period,
        page: target,
      );
      if (!mounted || token != request) return;
      setState(() {
        report = result;
        page = target;
        payments =
            next
                ? {
                  for (final p in [...payments, ...result.payments]) p['id']: p,
                }.values.toList()
                : result.payments;
      });
    } catch (error) {
      if (mounted && token == request) {
        setState(() => failure = errorText(error));
      }
    } finally {
      if (mounted && token == request) setState(() => busy = false);
    }
  }

  Widget amount(String label, int value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
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

  @override
  Widget build(BuildContext context) {
    final data = report;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (data != null) ...[
          _MetricGrid(
            metrics: [
              _Metric(
                'Nota masuk',
                '${data.count}',
                Icons.receipt_long_outlined,
                'Berdasarkan tanggal masuk',
              ),
              _Metric(
                'Belum selesai',
                '${data.pending}',
                Icons.pending_actions_outlined,
                'Layanan masih Masuk / Dikerjakan',
              ),
              _Metric(
                'Penerimaan pelanggan',
                rp(data.received),
                Icons.payments_outlined,
                'Berdasarkan tanggal pembayaran',
              ),
              _Metric(
                'Pekerjaan terlambat',
                '${data.overdue}',
                Icons.event_busy_outlined,
                'Dari nota pada periode ini',
              ),
            ],
          ),
          if (!widget.compact) ...[
            const SizedBox(height: 16),
            _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Nilai nota masuk',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  amount('Nilai sebelum diskon', data.gross),
                  amount('Diskon', data.discount),
                  amount('Omzet nota', data.revenue),
                  amount(
                    'Sisa tagihan nota periode ini',
                    data.outstandingPeriod,
                  ),
                  const Divider(),
                  amount('Piutang semua tanggal', data.outstandingAll),
                  const Text(
                    'Sisa tagihan dihitung dari pembayaran aktif terbaru, termasuk pembayaran setelah periode ini.',
                    style: TextStyle(
                      fontSize: 12,
                      color: PeronaColors.muted,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Penerimaan pada periode ini',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  amount('Tunai', data.cash),
                  amount('QRIS', data.qris),
                  amount('Transfer', data.transfer),
                  const Divider(),
                  amount('Total penerimaan', data.received),
                  Text(
                    '${data.receiptCount} pembayaran aktif · Termasuk pelunasan nota lama',
                    style: const TextStyle(
                      fontSize: 12,
                      color: PeronaColors.muted,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'PDF rekap mengikuti tanggal masuk nota. Penerimaan di sini mengikuti tanggal pembayaran.',
                    style: TextStyle(
                      fontSize: 12,
                      color: PeronaColors.muted,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Status pengerjaan',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text('Belum selesai: ${data.pending}'),
                  Text('Siap diambil: ${data.ready}'),
                  Text('Sudah diambil: ${data.pickedUp}'),
                  Text('Estimasi hari ini: ${data.dueToday}'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const _SectionTitle(
              title: 'Rincian penerimaan',
              subtitle: 'Ketuk pelanggan untuk membuka nota asal.',
            ),
            const SizedBox(height: 8),
            for (final receipt in payments)
              Card(
                child: InkWell(
                  key: ValueKey('operational-receipt-${receipt['id']}'),
                  onTap: () async {
                    await widget.onOrder(receipt['order_id'] as String);
                    if (mounted) await load();
                  },
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${receipt['customer_name']} · Nota #${receipt['order_number']}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${stamp(receipt['paid_at'])} WIB · ${receipt['method']}',
                        ),
                        Text(
                          rp(receipt['amount']),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: PeronaColors.forest,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          'Masuk ${DateFormat('dd/MM/yyyy').format(jakarta(DateTime.parse(receipt['order_at'] as String)))}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: PeronaColors.muted,
                          ),
                        ),
                        Text(
                          'Dicatat oleh ${receipt['operator_name']}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: PeronaColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (!busy && payments.isEmpty)
              const _Notice(
                icon: Icons.payments_outlined,
                text: 'Belum ada penerimaan pada periode ini.',
              ),
            if (!busy && failure == null && payments.length < data.receiptCount)
              OutlinedButton(
                key: const ValueKey('more-operational-receipts'),
                onPressed: () => load(next: true),
                child: const Text('Muat pembayaran lainnya'),
              ),
          ],
        ],
        if (busy)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (failure != null)
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  failure!,
                  style: const TextStyle(color: PeronaColors.muted),
                ),
                TextButton(
                  onPressed: () => load(next: payments.isNotEmpty),
                  child: const Text('Coba muat laporan'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

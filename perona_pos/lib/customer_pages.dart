part of 'main.dart';

String _customerPeriodLabel(Period period) {
  final format = DateFormat('dd/MM/yyyy');
  return '${format.format(jakarta(period.start))} – '
      '${format.format(jakarta(period.end.subtract(const Duration(days: 1))))}';
}

class _CustomerRankingPanel extends StatefulWidget {
  final Repository repo;
  final Period initialPeriod;
  final CustomerRanking? seed;
  final bool compact;
  final ValueChanged<Period> onPeriodChanged;
  final Future<void> Function(CustomerVisits, Period) onCustomer;
  final Future<void> Function(CustomerRanking)? onShowAll;
  const _CustomerRankingPanel({
    required this.repo,
    required this.initialPeriod,
    required this.onPeriodChanged,
    required this.onCustomer,
    this.seed,
    this.compact = true,
    this.onShowAll,
  });

  @override
  State<_CustomerRankingPanel> createState() => _CustomerRankingPanelState();
}

class _CustomerRankingPanelState extends State<_CustomerRankingPanel> {
  late Period period;
  late Future<CustomerRanking> future;

  @override
  void initState() {
    super.initState();
    period = widget.initialPeriod;
    future = widget.seed != null ? Future.value(widget.seed!) : load();
  }

  @override
  void didUpdateWidget(covariant _CustomerRankingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (period.start != widget.initialPeriod.start ||
        period.end != widget.initialPeriod.end) {
      period = widget.initialPeriod;
      future = widget.seed != null ? Future.value(widget.seed!) : load();
    } else if (widget.seed != null && widget.seed != oldWidget.seed) {
      future = Future.value(widget.seed!);
    }
  }

  Future<CustomerRanking> load() async {
    final selected = period;
    return CustomerRanking(await widget.repo.allOrders(selected), selected);
  }

  Future<void> refresh() async {
    final next = load();
    setState(() {
      future = next;
    });
    try {
      await next;
    } catch (_) {
      // The error and retry action are displayed below.
    }
  }

  Future<void> choosePeriod() async {
    final start = jakarta(period.start);
    final end = jakarta(period.end.subtract(const Duration(days: 1)));
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100, 12, 31),
      currentDate: jakarta(DateTime.now()),
      initialDateRange: DateTimeRange(
        start: DateTime(start.year, start.month, start.day),
        end: DateTime(end.year, end.month, end.day),
      ),
      helpText: 'Pilih periode pelanggan',
      saveText: 'Terapkan',
      confirmText: 'Terapkan',
      cancelText: 'Batal',
      fieldStartLabelText: 'Tanggal mulai',
      fieldEndLabelText: 'Tanggal akhir',
      errorInvalidRangeText: 'Tanggal akhir harus setelah tanggal mulai.',
    );
    if (picked == null || !mounted) return;
    period = Period.betweenDates(picked.start, picked.end);
    widget.onPeriodChanged(period);
    await refresh();
  }

  Future<void> openCustomer(CustomerVisits customer) async {
    await widget.onCustomer(customer, period);
    if (mounted) await refresh();
  }

  Widget rankingRow(CustomerVisits customer, int rank) => InkWell(
    key: ValueKey('customer-rank-$rank'),
    onTap: () => openCustomer(customer),
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: rank == 1 ? PeronaColors.lime : PeronaColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$rank',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: PeronaColors.forest,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    Text(
                      '${customer.visits} kunjungan',
                      style: const TextStyle(
                        color: PeronaColors.forest,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      rp(customer.total),
                      style: const TextStyle(color: PeronaColors.muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: PeronaColors.muted),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.compact ? 'Top 5 pelanggan' : 'Pelanggan paling sering datang',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        const Text(
          '1 nota = 1 kunjungan',
          style: TextStyle(fontSize: 12, color: PeronaColors.muted),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          key: const ValueKey('customer-date-range'),
          onPressed: choosePeriod,
          icon: const Icon(Icons.date_range_outlined, size: 20),
          label: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_customerPeriodLabel(period)),
              const Text('Ubah tanggal · WIB', style: TextStyle(fontSize: 12)),
            ],
          ),
          style: TextButton.styleFrom(
            alignment: Alignment.centerLeft,
            backgroundColor: PeronaColors.background,
            padding: const EdgeInsets.all(12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 8),
        FutureBuilder<CustomerRanking>(
          future: future,
          builder: (context, result) {
            if (result.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (result.hasError) {
              return Column(
                children: [
                  const SizedBox(height: 12),
                  const Text(
                    'Peringkat belum bisa dimuat',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(errorText(result.error!)),
                  TextButton(
                    onPressed: refresh,
                    child: const Text('Coba lagi'),
                  ),
                ],
              );
            }
            final ranking = result.data!;
            final rows =
                widget.compact
                    ? ranking.customers.take(5).toList()
                    : ranking.customers;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (rows.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'Belum ada pelanggan pada periode ini.',
                      style: TextStyle(color: PeronaColors.muted),
                    ),
                  ),
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  rankingRow(rows[i], i + 1),
                ],
                if (widget.compact && rows.isNotEmpty)
                  TextButton.icon(
                    key: const ValueKey('all-customers'),
                    onPressed: () => widget.onShowAll!(ranking),
                    label: const Text('Lihat semua pelanggan'),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    iconAlignment: IconAlignment.end,
                  ),
              ],
            );
          },
        ),
      ],
    );
    if (widget.compact) return content;
    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [content],
      ),
    );
  }
}

class _CustomerHistoryPage extends StatefulWidget {
  final Repository repo;
  final CustomerVisits customer;
  final Period period;
  final bool owner;
  final List<Json> services, staff;
  const _CustomerHistoryPage({
    required this.repo,
    required this.customer,
    required this.period,
    required this.owner,
    required this.services,
    required this.staff,
  });

  @override
  State<_CustomerHistoryPage> createState() => _CustomerHistoryPageState();
}

class _CustomerHistoryPageState extends State<_CustomerHistoryPage> {
  late Future<CustomerVisits?> future;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<CustomerVisits?> load() async => CustomerRanking(
    await widget.repo.allOrders(widget.period),
    widget.period,
  ).find(widget.customer.identity);

  Future<void> refresh() async {
    final next = load();
    setState(() {
      future = next;
    });
    try {
      await next;
    } catch (_) {
      // FutureBuilder displays a retry action.
    }
  }

  Future<void> detail(String id) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => OrderDetail(
              repo: widget.repo,
              id: id,
              owner: widget.owner,
              services: widget.services,
              staff: widget.staff,
            ),
      ),
    );
    if (mounted) await refresh();
  }

  Widget receipt(Json order) => Card(
    key: ValueKey('customer-receipt-${order['id']}'),
    child: InkWell(
      onTap: () => detail(order['id'] as String),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  'Nota #${order['number']}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  rp(order['total']),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: PeronaColors.forest,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${stamp(order['created_at'])} WIB',
              style: const TextStyle(fontSize: 12, color: PeronaColors.muted),
            ),
            const SizedBox(height: 10),
            for (final item in (order['items'] as List? ?? []))
              Text('${item['name']} × ${item['quantity']}'),
            const SizedBox(height: 8),
            const Row(
              children: [
                Text(
                  'Lihat detail nota',
                  style: TextStyle(fontSize: 12, color: PeronaColors.forest),
                ),
                SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: PeronaColors.forest,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Riwayat pelanggan')),
    body: FutureBuilder<CustomerVisits?>(
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
                title: 'Riwayat belum bisa dimuat',
                description: errorText(result.error!),
                action: FilledButton(
                  onPressed: refresh,
                  child: const Text('Coba lagi'),
                ),
              ),
            ],
          );
        }
        final customer = result.data;
        return RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              _SectionTitle(
                title: customer?.name ?? widget.customer.name,
                subtitle: '${_customerPeriodLabel(widget.period)} · WIB',
              ),
              if ((customer?.phone ?? widget.customer.phone)
                  .trim()
                  .isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  customer?.phone ?? widget.customer.phone,
                  style: const TextStyle(color: PeronaColors.muted),
                ),
              ],
              const SizedBox(height: 16),
              _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${customer?.visits ?? 0} kunjungan',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text('Total transaksi ${rp(customer?.total ?? 0)}'),
                    const SizedBox(height: 4),
                    const Text(
                      'Berdasarkan nilai nota, termasuk yang belum lunas.',
                      style: TextStyle(fontSize: 12, color: PeronaColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (customer == null)
                const _EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'Belum ada nota',
                  description: 'Tidak ada nota pelanggan pada periode ini.',
                ),
              for (final order in customer?.orders ?? <Json>[]) ...[
                receipt(order),
                const SizedBox(height: 12),
              ],
            ],
          ),
        );
      },
    ),
  );
}

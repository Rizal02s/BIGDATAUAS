part of 'main.dart';

class _OrderFilterControls extends StatelessWidget {
  final TextEditingController controller;
  final OrderFilter filter;
  final ValueChanged<OrderFilter> onChanged;
  final VoidCallback onReset;
  const _OrderFilterControls({
    required this.controller,
    required this.filter,
    required this.onChanged,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('order-search'),
          controller: controller,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: 'Cari order',
            hintText: 'Nama, WA, atau nomor nota',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon:
                controller.text.isEmpty
                    ? null
                    : IconButton(
                      tooltip: 'Hapus pencarian',
                      onPressed: () {
                        controller.clear();
                        onChanged(filter.copyWith(query: ''));
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
          ),
          onChanged: (value) => onChanged(filter.copyWith(query: value)),
          onSubmitted: (_) => FocusScope.of(context).unfocus(),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<WorkFilter>(
          key: ValueKey(('order-work-filter', filter.work)),
          initialValue: filter.work,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Status pengerjaan'),
          items: [
            for (final value in WorkFilter.values)
              DropdownMenuItem(value: value, child: Text(value.label)),
          ],
          onChanged: (value) {
            if (value != null) onChanged(filter.copyWith(work: value));
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<PaymentFilter>(
          key: ValueKey(('order-payment-filter', filter.payment)),
          initialValue: filter.payment,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Status pembayaran'),
          items: [
            for (final value in PaymentFilter.values)
              DropdownMenuItem(value: value, child: Text(value.label)),
          ],
          onChanged: (value) {
            if (value != null) onChanged(filter.copyWith(payment: value));
          },
        ),
        const SizedBox(height: 10),
        const Text(
          'Pencarian mengikuti periode yang dipilih di atas.',
          style: TextStyle(fontSize: 12, color: PeronaColors.muted),
        ),
        if (filter.work == WorkFilter.notPickedUp) ...[
          const SizedBox(height: 6),
          const Text(
            'Belum diambil mencakup layanan yang masih dikerjakan dan yang sudah selesai.',
            style: TextStyle(fontSize: 12, color: PeronaColors.muted),
          ),
        ],
        if (filter.payment == PaymentFilter.outstanding) ...[
          const SizedBox(height: 6),
          const Text(
            'Belum lunas mencakup belum bayar dan DP.',
            style: TextStyle(fontSize: 12, color: PeronaColors.muted),
          ),
        ],
        if (filter.active)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('reset-order-filters'),
              onPressed: onReset,
              icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
              label: const Text('Reset pencarian & filter'),
            ),
          ),
      ],
    ),
  );
}

class _OrderFilteredResults extends StatefulWidget {
  final Repository repo;
  final Period period;
  final String? workerId;
  final OrderFilter filter;
  final int revision;
  final List<Widget> Function(List<Json>) cards;
  final VoidCallback onReset;
  const _OrderFilteredResults({
    super.key,
    required this.repo,
    required this.period,
    required this.workerId,
    required this.filter,
    required this.revision,
    required this.cards,
    required this.onReset,
  });

  @override
  State<_OrderFilteredResults> createState() => _OrderFilteredResultsState();
}

class _OrderFilteredResultsState extends State<_OrderFilteredResults>
    with AutomaticKeepAliveClientMixin {
  late Future<List<Json>> future;
  int page = 0;
  static const pageSize = 30;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<List<Json>> load() =>
      widget.repo.allOrders(widget.period, workerId: widget.workerId);

  @override
  void didUpdateWidget(covariant _OrderFilteredResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    final dataChanged =
        widget.period.start != oldWidget.period.start ||
        widget.period.end != oldWidget.period.end ||
        widget.workerId != oldWidget.workerId ||
        widget.repo != oldWidget.repo ||
        widget.revision != oldWidget.revision;
    if (dataChanged) future = load();
    if (dataChanged ||
        widget.filter.query != oldWidget.filter.query ||
        widget.filter.work != oldWidget.filter.work ||
        widget.filter.payment != oldWidget.filter.payment) {
      page = 0;
    }
  }

  void retry() => setState(() {
    future = load();
    page = 0;
  });

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<Json>>(
      future: future,
      builder: (context, result) {
        if (result.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Mencari order dalam periode ini…'),
              ],
            ),
          );
        }
        if (result.hasError) {
          return _EmptyState(
            icon: Icons.wifi_off_rounded,
            title: 'Pencarian belum bisa dimuat',
            description: errorText(result.error!),
            action: FilledButton(
              onPressed: retry,
              child: const Text('Coba lagi'),
            ),
          );
        }
        final matches = widget.filter.apply(
          result.data!,
          widget.period,
          workerId: widget.workerId,
        );
        if (matches.isEmpty) {
          return _EmptyState(
            icon: Icons.search_off_rounded,
            title: 'Tidak ada order yang cocok',
            description:
                'Coba nama, nomor WA, nomor nota, status, atau periode lain.',
            action: TextButton(
              onPressed: widget.onReset,
              child: const Text('Reset pencarian & filter'),
            ),
          );
        }
        final visible = matches.skip(page * pageSize).take(pageSize).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${matches.length} order ditemukan',
              key: const ValueKey('order-result-count'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...widget.cards(visible),
            if (matches.length > pageSize)
              _Panel(
                padding: const EdgeInsets.all(8),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    TextButton(
                      key: const ValueKey('search-previous-page'),
                      onPressed:
                          page == 0 ? null : () => setState(() => page--),
                      child: const Text('Sebelumnya'),
                    ),
                    Text(
                      'Halaman ${page + 1} dari ${(matches.length / pageSize).ceil()}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    TextButton(
                      key: const ValueKey('search-next-page'),
                      onPressed:
                          (page + 1) * pageSize >= matches.length
                              ? null
                              : () => setState(() => page++),
                      child: const Text('Berikutnya'),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

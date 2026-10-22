part of 'main.dart';

const _workStatuses = ['Masuk', 'Dikerjakan', 'Selesai', 'Diambil'];

Future<void> _showOrderQuickAction(
  BuildContext context,
  Repository repo,
  String orderId, {
  required bool payment,
  String? workerId,
}) async {
  await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder:
        (_) => _OrderQuickAction(
          repo: repo,
          orderId: orderId,
          payment: payment,
          workerId: workerId,
        ),
  );
}

class _OrderQuickAction extends StatefulWidget {
  final Repository repo;
  final String orderId;
  final bool payment;
  final String? workerId;
  const _OrderQuickAction({
    required this.repo,
    required this.orderId,
    required this.payment,
    this.workerId,
  });

  @override
  State<_OrderQuickAction> createState() => _OrderQuickActionState();
}

class _OrderQuickActionState extends State<_OrderQuickAction> {
  late Future<Json> future;

  @override
  void initState() {
    super.initState();
    future = widget.repo.order(widget.orderId);
  }

  void reload() {
    final next = widget.repo.order(widget.orderId);
    setState(() {
      future = next;
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Json>(
    future: future,
    builder: (context, result) {
      if (result.connectionState != ConnectionState.done || result.hasError) {
        return AlertDialog(
          title: Text(widget.payment ? 'Pembayaran order' : 'Ubah pengerjaan'),
          content:
              result.hasError
                  ? Text(errorText(result.error!))
                  : const SizedBox(
                    height: 64,
                    child: Center(child: CircularProgressIndicator()),
                  ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
            if (result.hasError)
              FilledButton(onPressed: reload, child: const Text('Coba lagi')),
          ],
        );
      }
      final order = result.data!;
      if (widget.payment) {
        return PaymentDialog(
          repo: widget.repo,
          orderId: widget.orderId,
          remaining: money(order['total']) - paidTotal(order),
          order: order,
        );
      }
      return _OrderStatusDialog(
        key: ObjectKey(order),
        repo: widget.repo,
        order: order,
        workerId: widget.workerId,
        onReload: reload,
      );
    },
  );
}

class _OrderStatusDialog extends StatefulWidget {
  final Repository repo;
  final Json order;
  final String? workerId;
  final VoidCallback onReload;
  const _OrderStatusDialog({
    super.key,
    required this.repo,
    required this.order,
    required this.onReload,
    this.workerId,
  });

  @override
  State<_OrderStatusDialog> createState() => _OrderStatusDialogState();
}

class _OrderStatusDialogState extends State<_OrderStatusDialog> {
  late List<Json> items;
  final selected = <String, String>{};
  bool busy = false;
  String? failure;

  @override
  void initState() {
    super.initState();
    items =
        (widget.order['items'] as List)
            .map((item) => Json.from(item as Map))
            .where(
              (item) =>
                  widget.workerId == null ||
                  item['worker_id'] == widget.workerId,
            )
            .toList();
    for (final item in items) {
      selected[item['id'] as String] = item['status'] as String;
    }
  }

  List<Json> get changes => [
    for (final item in items)
      if (selected[item['id']] != item['status'])
        {'id': item['id'], 'status': selected[item['id']]},
  ];

  Future<void> save() async {
    if (busy || changes.isEmpty) return;
    setState(() {
      busy = true;
      failure = null;
    });
    try {
      await widget.repo.updateOrderStatuses(
        widget.order['id'] as String,
        money(widget.order['version']),
        changes,
      );
      if (mounted) Navigator.pop(context);
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
      title: const Text('Ubah pengerjaan'),
      scrollable: true,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('#${widget.order['number']} · ${widget.order['customer_name']}'),
          if (widget.workerId != null) ...[
            const SizedBox(height: 8),
            const Text('Hanya layanan yang ditugaskan kepadamu.'),
          ],
          if (items.isEmpty) const Text('Belum ada layanan untuk diubah.'),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final status in _workStatuses)
                  ChoiceChip(
                    label: Text(status),
                    selected: selected.values.every((value) => value == status),
                    onSelected:
                        busy
                            ? null
                            : (_) => setState(() {
                              selected.updateAll((_, _) => status);
                            }),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Pilih status di atas untuk semua layanan, atau atur per layanan di bawah.',
              style: TextStyle(fontSize: 12, color: PeronaColors.muted),
            ),
            for (final item in items) ...[
              const SizedBox(height: 16),
              Text(
                '${item['name']} × ${item['quantity']}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey(
                  'item-status-${item['id']}-${selected[item['id']]}',
                ),
                initialValue: selected[item['id']],
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Status pengerjaan',
                ),
                items: [
                  for (final status in _workStatuses)
                    DropdownMenuItem(value: status, child: Text(status)),
                ],
                onChanged:
                    busy
                        ? null
                        : (value) => setState(() {
                          if (value != null) {
                            selected[item['id'] as String] = value;
                          }
                        }),
              ),
            ],
          ],
          if (failure != null) ...[
            const SizedBox(height: 16),
            Text(
              failure!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        if (failure != null)
          TextButton(
            onPressed: busy ? null : widget.onReload,
            child: const Text('Muat ulang'),
          ),
        FilledButton(
          onPressed: busy || changes.isEmpty ? null : save,
          child: Text(busy ? 'Menyimpan…' : 'Simpan status'),
        ),
      ],
    ),
  );
}

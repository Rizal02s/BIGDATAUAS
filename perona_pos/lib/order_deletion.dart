part of 'main.dart';

Future<int?> _showOrderDeletion(
  BuildContext context,
  Repository repo, {
  DateTime? date,
  Json? order,
}) async {
  if (repo.accessRole != 'owner') return null;
  final deleted = await showDialog<int>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _OrderDeletionDialog(repo: repo, date: date, order: order),
  );
  if (context.mounted && deleted != null && deleted > 0) {
    message(context, '$deleted order berhasil dihapus dari rekap.');
  }
  return deleted;
}

class _OrderDeletionDialog extends StatefulWidget {
  final Repository repo;
  final DateTime? date;
  final Json? order;
  const _OrderDeletionDialog({required this.repo, this.date, this.order});

  @override
  State<_OrderDeletionDialog> createState() => _OrderDeletionDialogState();
}

class _OrderDeletionDialogState extends State<_OrderDeletionDialog> {
  List<Json> orders = [];
  bool loading = true, deleting = false, attempted = false;
  int deleted = 0;
  String? failure;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      failure = null;
    });
    try {
      // Snapshot every page before deleting; deleting while paging would skip rows.
      final rows =
          widget.order != null
              ? [await widget.repo.order(widget.order!['id'] as String)]
              : await widget.repo.allOrders(
                Period.forDate(widget.date!, 'day'),
              );
      if (mounted) setState(() => orders = rows);
    } catch (error) {
      if (mounted) setState(() => failure = errorText(error));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> remove() async {
    if (deleting ||
        attempted ||
        loading ||
        orders.isEmpty ||
        widget.repo.accessRole != 'owner') {
      return;
    }
    setState(() {
      deleting = true;
      attempted = true;
    });
    try {
      for (final order in orders) {
        await widget.repo.delete(order, 'Dihapus oleh owner.');
        if (!mounted) return;
        setState(() => deleted++);
      }
      if (mounted) Navigator.pop(context, deleted);
    } catch (error) {
      if (mounted) {
        setState(
          () =>
              failure =
                  '$deleted/${orders.length} order terkonfirmasi dihapus. '
                  'Proses dihentikan. ${errorText(error)} '
                  'Tutup lalu periksa data terbaru sebelum mencoba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !deleting,
    child: AlertDialog(
      title: Text(widget.date == null ? 'Hapus order?' : 'Hapus semua order?'),
      scrollable: true,
      content:
          loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.date != null)
                    Text(
                      'Tanggal ${DateFormat('dd/MM/yyyy').format(widget.date!)} · WIB',
                    ),
                  if (failure != null)
                    Text(
                      failure!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    )
                  else if (orders.isEmpty)
                    const Text('Belum ada order pada tanggal ini.')
                  else ...[
                    const SizedBox(height: 12),
                    Text(
                      widget.order == null
                          ? 'Yakin ingin menghapus semua ${orders.length} order pada tanggal ini?'
                          : 'Yakin ingin menghapus order #${orders.single['number']} · ${orders.single['customer_name']}?',
                    ),
                  ],
                  if (deleting) ...[
                    const SizedBox(height: 16),
                    LinearProgressIndicator(value: deleted / orders.length),
                    const SizedBox(height: 8),
                    Text('Menghapus $deleted/${orders.length} order…'),
                  ],
                ],
              ),
      actions: [
        TextButton(
          onPressed: deleting ? null : () => Navigator.pop(context),
          child: Text(
            failure != null || orders.isEmpty && !loading ? 'Tutup' : 'Tidak',
          ),
        ),
        if (failure != null && !attempted)
          TextButton(onPressed: load, child: const Text('Coba lagi')),
        if (!loading && failure == null && orders.isNotEmpty)
          FilledButton(
            onPressed: deleting ? null : remove,
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Ya'),
          ),
      ],
    ),
  );
}

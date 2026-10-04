part of 'main.dart';

class _OrderDayPage extends StatefulWidget {
  final Repository repo;
  final DateTime date;
  final bool owner;
  final String? workerId;
  final List<Json> services, staff;
  const _OrderDayPage({
    required this.repo,
    required this.date,
    required this.owner,
    required this.workerId,
    required this.services,
    required this.staff,
  });

  @override
  State<_OrderDayPage> createState() => _OrderDayPageState();
}

class _OrderDayPageState extends State<_OrderDayPage> {
  List<Json> orders = [];
  int page = 0, request = 0;
  bool busy = true;
  String? failure;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final token = ++request;
    setState(() {
      busy = true;
      failure = null;
    });
    try {
      final result = await widget.repo.orders(
        Period.forDate(widget.date, 'day'),
        page,
        workerId: widget.workerId,
      );
      if (mounted && token == request) setState(() => orders = result);
    } catch (error) {
      if (mounted && token == request) {
        setState(() => failure = errorText(error));
      }
    } finally {
      if (mounted && token == request) setState(() => busy = false);
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
    if (mounted) await load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('Order ${DateFormat('dd/MM/yyyy').format(widget.date)}'),
      actions: [
        IconButton(
          onPressed: busy ? null : load,
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Muat ulang',
        ),
      ],
    ),
    body:
        busy
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    widget.workerId == null
                        ? 'Semua order · WIB'
                        : 'Pekerjaan saya · WIB',
                    style: const TextStyle(color: PeronaColors.muted),
                  ),
                  const SizedBox(height: 16),
                  if (failure != null)
                    _EmptyState(
                      icon: Icons.wifi_off_rounded,
                      title: 'Data belum bisa dimuat',
                      description: failure!,
                      action: FilledButton(
                        onPressed: load,
                        child: const Text('Coba lagi'),
                      ),
                    )
                  else ...[
                    if (orders.isEmpty)
                      _EmptyState(
                        icon: Icons.event_note_outlined,
                        title:
                            page == 0
                                ? 'Belum ada order pada tanggal ini'
                                : 'Tidak ada order lainnya',
                        description:
                            widget.workerId == null
                                ? 'Kembali untuk memilih tanggal lainnya.'
                                : 'Tidak ada layanan yang ditugaskan kepadamu pada halaman ini.',
                      ),
                    for (final order in orders)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _OrderCard(
                          order: order,
                          workerId: widget.workerId,
                          onTap: () => detail(order['id'] as String),
                        ),
                      ),
                    if (page > 0 || orders.length == 30)
                      _Panel(
                        padding: const EdgeInsets.all(8),
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            TextButton(
                              onPressed:
                                  page == 0
                                      ? null
                                      : () {
                                        setState(() => page--);
                                        load();
                                      },
                              child: const Text('Sebelumnya'),
                            ),
                            Text('Halaman ${page + 1}'),
                            TextButton(
                              onPressed:
                                  orders.length < 30
                                      ? null
                                      : () {
                                        setState(() => page++);
                                        load();
                                      },
                              child: const Text('Berikutnya'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
  );
}

part of 'main.dart';

class _OrderDeadlineLabel extends StatelessWidget {
  final Json order;
  final String? workerId;
  final bool showMissing;
  const _OrderDeadlineLabel({
    required this.order,
    this.workerId,
    this.showMissing = false,
  });

  @override
  Widget build(BuildContext context) {
    final due = orderDueDate(order);
    if (due == null && !showMissing) return const SizedBox.shrink();
    final pending = orderNeedsWork(order, workerId: workerId);
    final state = orderDeadline(order);
    final late = pending && state == DeadlineFilter.overdue;
    final suffix =
        !pending
            ? ' · Pengerjaan selesai'
            : late
            ? ' · Terlambat'
            : state == DeadlineFilter.today
            ? ' · Hari ini'
            : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        due == null
            ? 'Estimasi selesai belum diisi'
            : 'Estimasi ${DateFormat('dd/MM/yyyy').format(due)}$suffix',
        style: TextStyle(
          fontSize: 12,
          height: 1.5,
          fontWeight: FontWeight.w600,
          color:
              late ? Theme.of(context).colorScheme.error : PeronaColors.forest,
        ),
      ),
    );
  }
}

class WorkQueuePage extends StatefulWidget {
  final Repository repo;
  final List<Json> services, staff;
  final String? workerId;
  const WorkQueuePage({
    super.key,
    required this.repo,
    required this.services,
    required this.staff,
    this.workerId,
  });
  @override
  State<WorkQueuePage> createState() => _WorkQueuePageState();
}

class _WorkQueuePageState extends State<WorkQueuePage> {
  DeadlineFilter filter = DeadlineFilter.all;
  List<Json> rows = [];
  int page = 0, request = 0;
  bool busy = true, more = false, mine = true;
  String? failure;
  String? get workerId => mine ? widget.workerId : null;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool next = false}) async {
    final token = ++request;
    final nextPage = next ? page + 1 : 0;
    setState(() {
      busy = true;
      failure = null;
      if (!next) rows = [];
    });
    try {
      final result = await widget.repo.workQueue(
        filter,
        nextPage,
        workerId: workerId,
      );
      if (!mounted || token != request) return;
      setState(() {
        page = nextPage;
        rows = next ? [...rows, ...result] : result;
        more = result.length == 30;
      });
    } catch (error) {
      if (mounted && token == request) {
        setState(() => failure = errorText(error));
      }
    } finally {
      if (mounted && token == request) setState(() => busy = false);
    }
  }

  Future<void> detail(Json order) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => OrderDetail(
              repo: widget.repo,
              id: order['id'] as String,
              services: widget.services,
              staff: widget.staff,
              owner: widget.repo.accessRole == 'owner',
            ),
      ),
    );
    if (mounted) await load();
  }

  Future<void> status(Json order) async {
    await _showOrderQuickAction(
      context,
      widget.repo,
      order['id'] as String,
      payment: false,
      workerId: workerId,
    );
    if (mounted) await load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Prioritas pengerjaan'),
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
          const Text(
            'Semua tanggal order · WIB',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Layanan yang masih Masuk atau Dikerjakan. Estimasi terdekat tampil lebih dulu; order tanpa estimasi ada di bawah.',
            style: TextStyle(color: PeronaColors.muted, height: 1.5),
          ),
          if (widget.workerId != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Pekerjaan saya'),
              value: mine,
              onChanged: (value) {
                setState(() => mine = value);
                load();
              },
            ),
          const SizedBox(height: 12),
          DropdownButtonFormField<DeadlineFilter>(
            initialValue: filter,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Estimasi selesai'),
            items:
                DeadlineFilter.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value.label),
                      ),
                    )
                    .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => filter = value);
                load();
              }
            },
          ),
          const SizedBox(height: 16),
          for (final order in rows)
            _OrderCard(
              order: order,
              workerId: workerId,
              onTap: () => detail(order),
              onWorkStatus: () => status(order),
              onPayment: () async {
                await _showOrderQuickAction(
                  context,
                  widget.repo,
                  order['id'] as String,
                  payment: true,
                );
                if (mounted) await load();
              },
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
              icon: Icons.task_alt,
              text: 'Tidak ada pekerjaan pada pilihan ini.',
            ),
          if (!busy && failure == null && more)
            OutlinedButton(
              onPressed: () => load(next: true),
              child: const Text('Muat lebih banyak'),
            ),
        ],
      ),
    ),
  );
}

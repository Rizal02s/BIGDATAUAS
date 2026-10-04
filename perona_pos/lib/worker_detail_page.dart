part of 'main.dart';

class _WorkerDetailPage extends StatefulWidget {
  final Repository repo;
  final Period period;
  final String workerId, name;
  final List<Json> staff, services;
  const _WorkerDetailPage({
    required this.repo,
    required this.period,
    required this.workerId,
    required this.name,
    required this.staff,
    required this.services,
  });
  @override
  State<_WorkerDetailPage> createState() => _WorkerDetailPageState();
}

class _WorkerDetailPageState extends State<_WorkerDetailPage> {
  late Future<WorkerReport> future;
  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<WorkerReport> load() async {
    if (!widget.repo.canViewWages) {
      throw StateError('Akses ongkos tidak tersedia.');
    }
    final orders = await widget.repo.allOrders(
      widget.period,
      workerId: widget.workerId,
    );
    return WorkerReport(reportOrders(orders, widget.period), widget.workerId);
  }

  Future<void> detail(String id) async {
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
    if (mounted) {
      setState(() {
        future = load();
      });
    }
  }

  void export() => Navigator.of(context).push(
    MaterialPageRoute(
      builder:
          (_) => PdfExportPage(
            title: 'PDF ongkos ${widget.name}',
            filename: pdfFileName(
              'ongkos-${widget.name}-${periodLabel(widget.period)}',
            ),
            description:
                'Rincian ongkos ${widget.name} pada ${periodLabel(widget.period)}. Khusus owner dan teknisi.',
            generate: () async {
              final report = await load();
              return (await PeronaPdf.load()).worker(
                report,
                widget.name,
                widget.period,
              );
            },
          ),
    ),
  );

  Widget cell(String text, double width, {bool bold = false}) => SizedBox(
    width: width,
    child: Text(
      text,
      style: TextStyle(
        fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
        height: 1.4,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Ongkos ${widget.name}')),
    body: FutureBuilder<WorkerReport>(
      future: future,
      builder: (context, result) {
        if (result.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (result.hasError) {
          return Center(
            child: _EmptyState(
              icon: Icons.wifi_off,
              title: 'Rincian belum bisa dimuat',
              description: errorText(result.error!),
              action: FilledButton(
                onPressed:
                    () => setState(() {
                      future = load();
                    }),
                child: const Text('Coba lagi'),
              ),
            ),
          );
        }
        final report = result.data!;
        return RefreshIndicator(
          onRefresh: () async {
            final next = load();
            setState(() {
              future = next;
            });
            await next;
          },
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _SectionTitle(
                title: widget.name,
                subtitle: '${periodLabel(widget.period)} · WIB',
              ),
              const SizedBox(height: 16),
              _HeroCard(
                label: 'Total hak upah tercatat',
                value: rp(report.total),
                description:
                    '${report.orderCount} order · ${report.quantity} unit / pasang layanan',
                icon: Icons.account_balance_wallet_outlined,
                footer: '${report.completed} unit selesai / diambil',
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: export,
                icon: const Icon(Icons.download_outlined),
                label: const Text('Unduh rincian PDF'),
              ),
              const SizedBox(height: 16),
              const _Notice(
                icon: Icons.info_outline,
                text:
                    'Ongkos diakui saat order masuk, termasuk pekerjaan yang belum selesai. Nilai ini belum menunjukkan gaji yang telah dibayarkan.',
              ),
              const SizedBox(height: 24),
              const _SectionTitle(
                title: 'Rincian pekerjaan',
                subtitle:
                    'Geser tabel ke samping. Ketuk baris untuk melihat detail order.',
              ),
              const SizedBox(height: 12),
              if (report.entries.isEmpty)
                const _EmptyState(
                  icon: Icons.assignment_outlined,
                  title: 'Belum ada pekerjaan',
                  description:
                      'Tidak ada layanan pegawai ini dalam periode terpilih.',
                ),
              if (report.entries.isNotEmpty)
                _Panel(
                  padding: EdgeInsets.zero,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      showCheckboxColumn: false,
                      headingRowColor: const WidgetStatePropertyAll(
                        PeronaColors.lime,
                      ),
                      dataRowMinHeight: 76,
                      dataRowMaxHeight: double.infinity,
                      columnSpacing: 16,
                      horizontalMargin: 14,
                      columns: const [
                        DataColumn(label: Text('Tanggal')),
                        DataColumn(label: Text('Nama customer')),
                        DataColumn(label: Text('Service layanan')),
                        DataColumn(label: Text('Jumlah'), numeric: true),
                        DataColumn(label: Text('Total ongkos'), numeric: true),
                      ],
                      rows: [
                        for (final e in report.entries)
                          DataRow(
                            onSelectChanged:
                                (_) => detail(e.order['id'] as String),
                            cells: [
                              DataCell(
                                cell(
                                  '${DateFormat('dd/MM/yyyy').format(jakarta(DateTime.parse(e.order['created_at'] as String)))}\n#${e.order['number']}',
                                  92,
                                ),
                              ),
                              DataCell(
                                cell(
                                  e.order['customer_name'] as String,
                                  120,
                                  bold: true,
                                ),
                              ),
                              DataCell(
                                cell('${e.item['name']}\n${e.status}', 180),
                              ),
                              DataCell(cell('${e.quantity}', 45)),
                              DataCell(cell(rp(e.wage), 110, bold: true)),
                            ],
                          ),
                      ],
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

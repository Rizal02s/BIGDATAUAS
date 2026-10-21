part of 'main.dart';

class _WorkerDetailPage extends StatefulWidget {
  final Repository repo;
  final Period period;
  final String? workerId;
  final String name;
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
    appBar: AppBar(
      title: Text(
        widget.workerId == null
            ? 'Rincian ongkos tim'
            : 'Ongkos ${widget.name}',
      ),
    ),
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
        final notes = report.notes;
        return RefreshIndicator(
          onRefresh: () async {
            final next = load();
            setState(() {
              future = next;
            });
            await next;
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              _SectionTitle(
                title: widget.name,
                subtitle:
                    '${DateFormat('dd/MM/yyyy').format(jakarta(widget.period.start))} – ${DateFormat('dd/MM/yyyy').format(jakarta(widget.period.end.subtract(const Duration(seconds: 1))))} · WIB',
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
              if (widget.workerId != null) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: export,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Unduh rincian PDF'),
                ),
              ],
              const SizedBox(height: 16),
              const _Notice(
                icon: Icons.info_outline,
                text:
                    'Ongkos diakui saat order masuk, termasuk pekerjaan yang belum selesai. Nilai ini belum menunjukkan gaji yang telah dibayarkan.',
              ),
              const SizedBox(height: 24),
              const _SectionTitle(
                title: 'Rincian ongkos per nota',
                subtitle:
                    'Geser tabel ke samping. Ketuk baris untuk melihat detail order.',
              ),
              const SizedBox(height: 12),
              if (report.entries.isEmpty)
                const _EmptyState(
                  icon: Icons.assignment_outlined,
                  title: 'Belum ada pekerjaan',
                  description: 'Tidak ada layanan dalam periode terpilih.',
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
                        DataColumn(label: Text('No')),
                        DataColumn(label: Text('Tanggal masuk')),
                        DataColumn(label: Text('Nama customer')),
                        DataColumn(label: Text('Jenis order')),
                        DataColumn(
                          label: Text('Total ongkos per nota'),
                          numeric: true,
                        ),
                      ],
                      rows: [
                        for (var i = 0; i < notes.length; i++)
                          DataRow(
                            key: ValueKey('wage-note-${notes[i].order['id']}'),
                            onSelectChanged:
                                (_) => detail(notes[i].order['id'] as String),
                            cells: [
                              DataCell(cell('${i + 1}', 36)),
                              DataCell(
                                cell(
                                  DateFormat('dd/MM/yyyy').format(
                                    jakarta(
                                      DateTime.parse(
                                        notes[i].order['created_at'] as String,
                                      ),
                                    ),
                                  ),
                                  92,
                                ),
                              ),
                              DataCell(
                                cell(
                                  '${notes[i].order['customer_name']}\nNota #${notes[i].order['number']}',
                                  120,
                                  bold: true,
                                ),
                              ),
                              DataCell(cell(notes[i].services, 180)),
                              DataCell(
                                cell(rp(notes[i].wage), 140, bold: true),
                              ),
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

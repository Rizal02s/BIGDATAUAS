part of 'main.dart';

class _PaymentDetailPage extends StatefulWidget {
  final Repository repo;
  final Period period;
  final PaymentCategory category;
  final bool owner;
  final List<Json> services, staff;
  const _PaymentDetailPage({
    required this.repo,
    required this.period,
    required this.category,
    required this.owner,
    required this.services,
    required this.staff,
  });

  @override
  State<_PaymentDetailPage> createState() => _PaymentDetailPageState();
}

class _PaymentDetailPageState extends State<_PaymentDetailPage> {
  late Future<PaymentOverview> future;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<PaymentOverview> load() async => PaymentOverview(
    await widget.repo.allOrders(widget.period),
    widget.period,
  );

  Future<void> refresh() async {
    final next = load();
    setState(() {
      future = next;
    });
    try {
      await next;
    } catch (_) {
      /* Error is displayed by FutureBuilder. */
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

  String description(Json order) {
    final remaining = orderRemaining(order);
    final paid = orderPaid(order);
    final status =
        remaining == 0
            ? 'Lunas'
            : paid > 0
            ? 'DP'
            : 'Belum bayar';
    final method = widget.category.method;
    return '${method == null ? 'Dibayar ${rp(paid)}' : '$method ${rp(orderPaidByMethod(order, method))}'}\n'
        '${method != null && orderPaidByMethod(order, method) != paid ? 'Total dibayar ${rp(paid)}\n' : ''}'
        'Tagihan ${rp(order['total'])} · $status'
        '${remaining > 0 ? '\nSisa ${rp(remaining)}' : ''}';
  }

  Widget cell(String text, double width, {bool bold = false}) => SizedBox(
    width: width,
    child: Text(
      text,
      style: TextStyle(
        height: 1.4,
        fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.category.label)),
    body: FutureBuilder<PaymentOverview>(
      future: future,
      builder: (context, result) {
        if (result.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (result.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _EmptyState(
                icon: Icons.wifi_off,
                title: 'Rincian belum bisa dimuat',
                description: errorText(result.error!),
                action: FilledButton(
                  onPressed: refresh,
                  child: const Text('Coba lagi'),
                ),
              ),
            ),
          );
        }
        final overview = result.data!;
        final rows = overview.ordersFor(widget.category);
        return RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              _SectionTitle(
                title: periodLabel(widget.period),
                subtitle:
                    '${overview.customerCountFor(widget.category)} customer · ${rows.length} nota · Tanggal masuk WIB',
              ),
              const SizedBox(height: 16),
              _Panel(
                child: _PriceLabel(
                  label:
                      widget.category == PaymentCategory.unpaid
                          ? 'Total sisa tagihan'
                          : 'Total ${widget.category.method}',
                  value: rp(overview.amountFor(widget.category)),
                ),
              ),
              const SizedBox(height: 16),
              if (rows.isEmpty)
                const _EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'Belum ada customer pada kategori ini',
                  description:
                      'Data mengikuti order yang masuk pada bulan terpilih.',
                )
              else ...[
                const Text(
                  'Geser tabel ke samping. Ketuk baris untuk membuka order.',
                  style: TextStyle(color: PeronaColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                _Panel(
                  padding: EdgeInsets.zero,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      showCheckboxColumn: false,
                      headingRowColor: const WidgetStatePropertyAll(
                        PeronaColors.lime,
                      ),
                      dataRowMinHeight: 80,
                      dataRowMaxHeight: double.infinity,
                      columnSpacing: 16,
                      horizontalMargin: 14,
                      columns: const [
                        DataColumn(label: Text('No')),
                        DataColumn(label: Text('Tanggal')),
                        DataColumn(label: Text('Nama customer')),
                        DataColumn(label: Text('Keterangan bayar')),
                      ],
                      rows: [
                        for (var i = 0; i < rows.length; i++)
                          DataRow(
                            key: ValueKey('payment-note-${rows[i]['id']}'),
                            onSelectChanged:
                                (_) => detail(rows[i]['id'] as String),
                            cells: [
                              DataCell(cell('${i + 1}', 36)),
                              DataCell(
                                cell(
                                  DateFormat('dd/MM/yyyy').format(
                                    jakarta(
                                      DateTime.parse(
                                        rows[i]['created_at'] as String,
                                      ),
                                    ),
                                  ),
                                  90,
                                ),
                              ),
                              DataCell(
                                cell(
                                  '${rows[i]['customer_name']}\nNota #${rows[i]['number']}',
                                  140,
                                  bold: true,
                                ),
                              ),
                              DataCell(cell(description(rows[i]), 240)),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
}

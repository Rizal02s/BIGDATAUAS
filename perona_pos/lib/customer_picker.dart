part of 'main.dart';

class _CustomerSuggestions extends StatefulWidget {
  final Repository repo;
  final String query;
  final ValueChanged<Json> onSelected;
  const _CustomerSuggestions({
    super.key,
    required this.repo,
    required this.query,
    required this.onSelected,
  });
  @override
  State<_CustomerSuggestions> createState() => _CustomerSuggestionsState();
}

class _CustomerSuggestionsState extends State<_CustomerSuggestions> {
  Timer? debounce;
  int request = 0;
  List<Json> rows = [];
  bool busy = true;
  String? failure;
  @override
  void initState() {
    super.initState();
    schedule();
  }

  @override
  void didUpdateWidget(covariant _CustomerSuggestions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) schedule();
  }

  void schedule() {
    debounce?.cancel();
    request++;
    rows = [];
    busy = true;
    failure = null;
    debounce = Timer(const Duration(milliseconds: 350), load);
  }

  Future<void> load() async {
    final token = ++request;
    final query = widget.query;
    setState(() {
      busy = true;
      failure = null;
    });
    try {
      final result = await widget.repo.customerSuggestions(query);
      if (mounted && token == request) {
        setState(() => rows = result.take(5).toList());
      }
    } catch (error) {
      if (mounted && token == request) {
        setState(() => failure = errorText(error));
      }
    } finally {
      if (mounted && token == request) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 6, bottom: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: PeronaColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Text(
            'Pilih pelanggan lama',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
        if (busy)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Mencari pelanggan…',
              style: TextStyle(fontSize: 12, color: PeronaColors.muted),
            ),
          )
        else if (failure != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  failure!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: PeronaColors.muted,
                  ),
                ),
                const Text(
                  'Kamu tetap bisa mengisi nama dan WhatsApp secara manual.',
                  style: TextStyle(fontSize: 12),
                ),
                TextButton(onPressed: load, child: const Text('Coba lagi')),
              ],
            ),
          )
        else if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Belum ada pelanggan yang cocok. Lanjutkan sebagai pelanggan baru.',
              style: TextStyle(fontSize: 12, color: PeronaColors.muted),
            ),
          )
        else
          for (final row in rows)
            InkWell(
              key: ValueKey('choose-customer-${row['identity']}'),
              borderRadius: BorderRadius.circular(12),
              onTap: () => widget.onSelected(row),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      row['customer_name'] as String,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      (row['phone'] as String? ?? '').isEmpty
                          ? 'Tanpa nomor WhatsApp'
                          : row['phone'] as String,
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      'Terakhir datang ${DateFormat('dd/MM/yyyy').format(jakarta(DateTime.parse(row['last_visit'] as String)))} · ${money(row['visits'])} kunjungan',
                      style: const TextStyle(
                        fontSize: 12,
                        color: PeronaColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    ),
  );
}

part of 'main.dart';

class HomePage extends StatefulWidget {
  final Repository repo;
  final Json profile;
  const HomePage({super.key, required this.repo, required this.profile});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Json> services = [], staff = [], orders = [];
  Json summary = {};
  DateTime date = jakarta(DateTime.now());
  String kind = 'day', catalogQuery = '';
  final catalogSearch = TextEditingController();
  int tab = 0, page = 0, request = 0;
  bool busy = true, mineOnly = true;
  String? failure;

  bool get owner => widget.profile['role'] == 'owner';
  String get userId => widget.profile['id'] as String;
  String get name => widget.profile['name'] as String? ?? 'Perona';
  Period get period => Period.forDate(date, kind);
  int get pendingCount => staff.where((p) => p['role'] == 'pending').length;
  int get ownWage => ((summary['wages'] as List?) ?? [])
      .where((w) => w['id'] == userId)
      .fold<int>(0, (sum, w) => sum + money(w['amount']));

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    catalogSearch.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final token = ++request;
    final workerId = !owner && (tab == 0 || mineOnly) ? userId : null;
    setState(() {
      busy = true;
      failure = null;
    });
    try {
      final result = await Future.wait<dynamic>([
        widget.repo.services(),
        widget.repo.staff(),
        widget.repo.orders(period, page, workerId: workerId),
        widget.repo.report(period),
      ]);
      if (!mounted || token != request) return;
      setState(() {
        services = result[0] as List<Json>;
        staff = result[1] as List<Json>;
        orders = result[2] as List<Json>;
        summary = result[3] as Json;
      });
    } catch (e) {
      if (mounted && token == request) setState(() => failure = errorText(e));
    } finally {
      if (mounted && token == request) setState(() => busy = false);
    }
  }

  Future<void> editor([Json? order]) async {
    final saved = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder:
            (_) => OrderEditor(
              repo: widget.repo,
              services: services,
              staff: staff,
              existing: order,
            ),
      ),
    );
    if (saved != null && mounted) {
      await load();
      if (mounted) await detail(saved);
    }
  }

  Future<void> detail(String id) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => OrderDetail(
              repo: widget.repo,
              id: id,
              owner: owner,
              services: services,
              staff: staff,
            ),
      ),
    );
    if (mounted) await load();
  }

  void selectTab(int value) {
    if (tab == value) return;
    setState(() {
      tab = value;
      page = 0;
    });
    load();
  }

  Future<void> chooseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(date.year, date.month, date.day),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() {
        date = picked;
        page = 0;
      });
      await load();
    }
  }

  Future<void> editService([Json? service]) async {
    if (!owner) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ServiceEditor(repo: widget.repo, existing: service),
      ),
    );
    if (mounted) await load();
  }

  String get dateLabel {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    if (kind == 'year') return '${date.year}';
    if (kind == 'month') return '${months[date.month - 1]} ${date.year}';
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 76,
      title: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(
                  'assets/perona-logo.png',
                  width: 148,
                  height: 46,
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                  semanticLabel: 'Perona Sepatu',
                ),
                Text(
                  owner ? 'Portal Owner' : 'Portal Pegawai',
                  style: const TextStyle(
                    fontSize: 12,
                    color: PeronaColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: busy ? null : load,
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Muat ulang',
        ),
        IconButton(
          onPressed: () => widget.repo.db.auth.signOut(),
          icon: const Icon(Icons.logout_rounded),
          tooltip: 'Keluar',
        ),
        const SizedBox(width: 4),
      ],
    ),
    body:
        busy
            ? const Center(child: CircularProgressIndicator())
            : failure != null
            ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _EmptyState(
                  icon: Icons.wifi_off_rounded,
                  title: 'Data belum bisa dimuat',
                  description: failure!,
                  action: FilledButton.icon(
                    onPressed: load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Coba lagi'),
                  ),
                ),
              ),
            )
            : RefreshIndicator(
              onRefresh: load,
              child: LayoutBuilder(
                builder:
                    (context, constraints) => ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        constraints.maxWidth > 960
                            ? (constraints.maxWidth - 920) / 2
                            : 20,
                        8,
                        constraints.maxWidth > 960
                            ? (constraints.maxWidth - 920) / 2
                            : 20,
                        28,
                      ),
                      children: switch (tab) {
                        0 => owner ? ownerHome() : staffHome(),
                        1 => orderList(),
                        2 => catalog(),
                        _ => owner ? people() : staffHome(),
                      },
                    ),
              ),
            ),
    bottomNavigationBar: DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: PeronaColors.border)),
      ),
      child: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: selectTab,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.space_dashboard_outlined),
            selectedIcon: const Icon(Icons.space_dashboard_rounded),
            label: owner ? 'Ringkasan' : 'Beranda',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Order',
          ),
          const NavigationDestination(
            icon: Icon(Icons.sell_outlined),
            selectedIcon: Icon(Icons.sell),
            label: 'Layanan',
          ),
          if (owner)
            const NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'Pegawai',
            ),
        ],
      ),
    ),
  );

  Widget greeting(String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Halo, $name',
          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(color: PeronaColors.muted, height: 1.5),
        ),
      ],
    ),
  );

  Widget periodPicker() => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'PERIODE REKAP',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: PeronaColors.muted,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 'day', label: Text('Harian')),
            ButtonSegment(value: 'month', label: Text('Bulanan')),
            ButtonSegment(value: 'year', label: Text('Tahunan')),
          ],
          selected: {kind},
          onSelectionChanged: (selection) {
            setState(() {
              kind = selection.single;
              page = 0;
            });
            load();
          },
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: chooseDate,
          icon: const Icon(Icons.calendar_month_outlined, size: 19),
          label: Text('$dateLabel  ·  WIB'),
          style: TextButton.styleFrom(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          ),
        ),
      ],
    ),
  );

  List<Widget> ownerHome() => [
    greeting('Pantau usaha dan kelola tim Perona Sepatu.'),
    periodPicker(),
    const SizedBox(height: 16),
    _HeroCard(
      label: 'Pembayaran masuk',
      value: rp(summary['cash']),
      description: 'Uang yang diterima pada periode terpilih.',
      icon: Icons.account_balance_wallet_outlined,
      footer:
          '${summary['count'] ?? 0} order masuk  ·  Nilai ${rp(summary['revenue'])}',
    ),
    const SizedBox(height: 16),
    FilledButton.icon(
      onPressed: () => editor(),
      icon: const Icon(Icons.add_rounded),
      label: const Text('Buat order baru'),
    ),
    const SizedBox(height: 16),
    _MetricGrid(
      metrics: [
        _Metric(
          'Nilai order',
          rp(summary['revenue']),
          Icons.receipt_long_outlined,
          'Tagihan setelah diskon',
        ),
        _Metric(
          'Ongkos tim',
          rp(summary['labor']),
          Icons.groups_outlined,
          'Hak upah saat order masuk',
        ),
        _Metric(
          'Piutang usaha',
          rp(summary['outstanding_all']),
          Icons.pending_actions,
          'Sisa tagihan seluruh periode',
        ),
        _Metric(
          'Diskon',
          rp(summary['discount']),
          Icons.local_offer_outlined,
          'Pada order periode ini',
        ),
      ],
    ),
    if (pendingCount > 0) ...[
      const SizedBox(height: 14),
      _Notice(
        icon: Icons.person_add_alt_1_outlined,
        text:
            '$pendingCount akun menunggu aktivasi. Buka Pegawai untuk memberi akses.',
        onTap: () => selectTab(3),
      ),
    ],
    const SizedBox(height: 24),
    const _SectionTitle(
      title: 'Ongkos kerja tim',
      subtitle: 'Hak upah dari order pada periode terpilih',
    ),
    const SizedBox(height: 12),
    wagesPanel(),
    const SizedBox(height: 16),
    _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sisa nilai order setelah ongkos',
            style: TextStyle(color: PeronaColors.muted),
          ),
          const SizedBox(height: 8),
          Text(
            rp(money(summary['revenue']) - money(summary['labor'])),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Belum dikurangi bahan, sewa, listrik, dan biaya lainnya.',
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: PeronaColors.muted,
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 24),
    _SectionTitle(
      title: 'Order terbaru',
      subtitle: 'Dari periode yang kamu pilih',
      action: TextButton(
        onPressed: () => selectTab(1),
        child: const Text('Lihat semua'),
      ),
    ),
    const SizedBox(height: 12),
    ...orderCards(preview: true),
  ];

  List<Widget> staffHome() => [
    greeting('Lihat tugas dan catat layanan pelanggan hari ini.'),
    periodPicker(),
    const SizedBox(height: 16),
    _HeroCard(
      label: 'Ongkos kerja saya',
      value: rp(ownWage),
      description: 'Hak ongkosmu dari order pada periode terpilih.',
      icon: Icons.work_outline_rounded,
      footer: 'Dicatat saat order masuk; belum menunjukkan pembayaran gaji.',
    ),
    const SizedBox(height: 16),
    FilledButton.icon(
      onPressed: () => editor(),
      icon: const Icon(Icons.add_rounded),
      label: const Text('Input order pelanggan'),
    ),
    const SizedBox(height: 12),
    _Notice(
      icon: Icons.tips_and_updates_outlined,
      text:
          'Buka order untuk memperbarui status, menambah foto, atau mencatat pembayaran.',
    ),
    const SizedBox(height: 24),
    _SectionTitle(
      title: 'Pekerjaan saya',
      subtitle: 'Order yang memiliki layanan atas namamu',
      action: TextButton(
        onPressed: () {
          setState(() => mineOnly = true);
          selectTab(1);
        },
        child: const Text('Lihat semua'),
      ),
    ),
    const SizedBox(height: 12),
    ...orderCards(preview: true, personal: true),
    const SizedBox(height: 20),
    OutlinedButton.icon(
      onPressed: () => selectTab(2),
      icon: const Icon(Icons.sell_outlined),
      label: const Text('Lihat daftar layanan & harga'),
    ),
  ];

  Widget wagesPanel() {
    final wages = (summary['wages'] as List?) ?? [];
    if (wages.isEmpty) {
      return const _EmptyState(
        icon: Icons.groups_outlined,
        title: 'Belum ada ongkos tercatat',
        description:
            'Ongkos tim muncul setelah order ditambahkan pada periode ini.',
      );
    }
    final total = money(summary['labor']);
    return _Panel(
      child: Column(
        children: [
          for (var i = 0; i < wages.length; i++) ...[
            if (i > 0) const Divider(),
            Row(
              children: [
                _Avatar(name: wages[i]['name'] as String),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    wages[i]['name'] as String,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    rp(wages[i]['amount']),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value:
                  total > 0
                      ? (money(wages[i]['amount']) / total).clamp(0, 1)
                      : 0,
              minHeight: 5,
              borderRadius: BorderRadius.circular(4),
              backgroundColor: PeronaColors.background,
              color: PeronaColors.forest,
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> orderList() => [
    const _SectionTitle(
      title: 'Daftar order',
      subtitle: 'Status layanan dan pembayaran pelanggan',
    ),
    const SizedBox(height: 20),
    periodPicker(),
    const SizedBox(height: 16),
    FilledButton.icon(
      onPressed: () => editor(),
      icon: const Icon(Icons.add),
      label: const Text('Buat order baru'),
    ),
    if (!owner) ...[
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        children: [
          ChoiceChip(
            label: const Text('Pekerjaan saya'),
            selected: mineOnly,
            onSelected: (_) {
              setState(() {
                mineOnly = true;
                page = 0;
              });
              load();
            },
          ),
          ChoiceChip(
            label: const Text('Semua order'),
            selected: !mineOnly,
            onSelected: (_) {
              setState(() {
                mineOnly = false;
                page = 0;
              });
              load();
            },
          ),
        ],
      ),
    ],
    const SizedBox(height: 20),
    ...orderCards(personal: !owner && mineOnly),
    const SizedBox(height: 12),
    _Panel(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
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
          Text('Halaman ${page + 1}', style: const TextStyle(fontSize: 12)),
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
  ];

  List<Widget> orderCards({bool preview = false, bool personal = false}) {
    if (orders.isEmpty) {
      return [
        _EmptyState(
          icon: Icons.inventory_2_outlined,
          title: personal ? 'Belum ada pekerjaan untukmu' : 'Belum ada order',
          description:
              personal
                  ? 'Order akan muncul ketika kamu dipilih sebagai penanggung jawab layanan pada periode ini.'
                  : 'Tambahkan order pertama atau pilih periode lain untuk melihat transaksi.',
        ),
      ];
    }
    final visible = preview ? orders.take(4) : orders;
    return visible
        .map(
          (order) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _OrderCard(
              order: order,
              workerId: personal ? userId : null,
              onTap: () => detail(order['id'] as String),
            ),
          ),
        )
        .toList();
  }

  List<Widget> catalog() {
    final visible =
        services
            .where(
              (s) =>
                  (owner || s['active'] == true) &&
                  '${s['name']} ${s['category']}'.toLowerCase().contains(
                    catalogQuery,
                  ),
            )
            .toList();
    return [
      _SectionTitle(
        title: owner ? 'Kelola layanan' : 'Daftar layanan',
        subtitle:
            owner
                ? 'Atur harga dan ongkos untuk order baru.'
                : 'Harga pelanggan dan ongkos per unit layanan.',
      ),
      const SizedBox(height: 20),
      TextField(
        key: const ValueKey('catalog-search'),
        controller: catalogSearch,
        decoration: const InputDecoration(
          hintText: 'Cari nama atau kategori layanan',
          prefixIcon: Icon(Icons.search_rounded),
        ),
        onChanged:
            (value) => setState(() => catalogQuery = value.toLowerCase()),
      ),
      const SizedBox(height: 14),
      if (owner) ...[
        FilledButton.icon(
          onPressed: () => editService(),
          icon: const Icon(Icons.add),
          label: const Text('Tambah layanan'),
        ),
        const SizedBox(height: 16),
        const _Notice(
          icon: Icons.info_outline,
          text:
              'Perubahan tarif berlaku untuk item baru. Tarif order lama tetap tersimpan.',
        ),
        const SizedBox(height: 16),
      ],
      Text(
        '${visible.length} layanan',
        style: const TextStyle(color: PeronaColors.muted),
      ),
      const SizedBox(height: 12),
      if (visible.isEmpty)
        const _EmptyState(
          icon: Icons.search_off,
          title: 'Layanan tidak ditemukan',
          description: 'Coba kata pencarian lain.',
        ),
      ...visible.map(
        (service) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        service['name'] as String,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (owner)
                      IconButton(
                        onPressed: () => editService(service),
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Edit layanan',
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Badge(label: service['category'] as String),
                    if (service['active'] != true)
                      const _Badge(label: 'Nonaktif', warning: true),
                  ],
                ),
                const Divider(),
                Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  children: [
                    _PriceLabel(
                      label: 'Harga pelanggan',
                      value: rp(service['price']),
                    ),
                    _PriceLabel(
                      label: 'Ongkos / unit',
                      value:
                          service['labor_fee'] == null
                              ? 'Belum ditetapkan'
                              : rp(service['labor_fee']),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> people() => [
    const _SectionTitle(
      title: 'Kelola pegawai',
      subtitle: 'Aktifkan akun dan atur akses tim.',
    ),
    const SizedBox(height: 20),
    _MetricGrid(
      metrics: [
        _Metric(
          'Akun aktif',
          '${staff.where((p) => ['owner', 'staff'].contains(p['role'])).length}',
          Icons.verified_user_outlined,
          'Owner dan pegawai',
        ),
        _Metric(
          'Menunggu',
          '$pendingCount',
          Icons.person_add_alt_1_outlined,
          'Perlu aktivasi owner',
        ),
      ],
    ),
    const SizedBox(height: 16),
    const _Notice(
      icon: Icons.info_outline,
      text:
          'Pegawai mendaftar dengan email sendiri. Pilih menu akses pada akun untuk mengaktifkannya.',
    ),
    const SizedBox(height: 20),
    ...([...staff]..sort(
      (a, b) => (a['role'] == 'pending' ? 0 : 1).compareTo(
        b['role'] == 'pending' ? 0 : 1,
      ),
    )).map(
      (person) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _Panel(
          child: Row(
            children: [
              _Avatar(name: person['name'] as String),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person['name'] as String,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    _Badge(
                      label: switch (person['role']) {
                        'owner' => 'Owner',
                        'staff' => 'Pegawai aktif',
                        'pending' => 'Menunggu aktivasi',
                        _ => 'Nonaktif',
                      },
                      warning: ['pending', 'disabled'].contains(person['role']),
                    ),
                  ],
                ),
              ),
              if (person['id'] == userId)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Text(
                    'Kamu',
                    style: TextStyle(fontSize: 12, color: PeronaColors.muted),
                  ),
                )
              else
                PopupMenuButton<String>(
                  tooltip: 'Atur akses',
                  onSelected: (role) async {
                    try {
                      await widget.repo.setRole(person['id'] as String, role);
                      await load();
                    } catch (e) {
                      if (mounted) message(context, errorText(e));
                    }
                  },
                  itemBuilder:
                      (_) => const [
                        PopupMenuItem(
                          value: 'staff',
                          child: Text('Aktifkan sebagai pegawai'),
                        ),
                        PopupMenuItem(
                          value: 'owner',
                          child: Text('Jadikan owner'),
                        ),
                        PopupMenuItem(
                          value: 'disabled',
                          child: Text('Nonaktifkan'),
                        ),
                      ],
                ),
            ],
          ),
        ),
      ),
    ),
  ];
}

class _Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _Panel({required this.child, this.padding = const EdgeInsets.all(18)});
  @override
  Widget build(BuildContext context) =>
      Card(child: Padding(padding: padding, child: child));
}

class _HeroCard extends StatelessWidget {
  final String label, value, description, footer;
  final IconData icon;
  const _HeroCard({
    required this.label,
    required this.value,
    required this.description,
    required this.footer,
    required this.icon,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: PeronaColors.brandGreen,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: PeronaColors.ink, size: 21),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: PeronaColors.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          value,
          style: const TextStyle(
            color: PeronaColors.ink,
            fontSize: 34,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: const TextStyle(
            color: PeronaColors.ink,
            fontSize: 12,
            height: 1.5,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Divider(color: PeronaColors.forest, height: 1),
        ),
        Text(
          footer,
          style: const TextStyle(
            color: PeronaColors.ink,
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ],
    ),
  );
}

class _Metric {
  final String label, value, caption;
  final IconData icon;
  const _Metric(this.label, this.value, this.icon, this.caption);
}

class _MetricGrid extends StatelessWidget {
  final List<_Metric> metrics;
  const _MetricGrid({required this.metrics});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      final largeText = MediaQuery.textScalerOf(context).scale(14) > 19;
      final columns =
          size.maxWidth < 300 || largeText
              ? 1
              : size.maxWidth > 760
              ? 4
              : 2;
      final width = (size.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children:
            metrics
                .map(
                  (metric) => SizedBox(
                    width: width,
                    child: _Panel(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            metric.icon,
                            color: PeronaColors.forest,
                            size: 21,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            metric.label,
                            style: const TextStyle(
                              fontSize: 12,
                              color: PeronaColors.muted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            metric.value,
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            metric.caption,
                            style: const TextStyle(
                              fontSize: 11,
                              color: PeronaColors.muted,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
      );
    },
  );
}

class _SectionTitle extends StatelessWidget {
  final String title, subtitle;
  final Widget? action;
  const _SectionTitle({
    required this.title,
    required this.subtitle,
    this.action,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          if (action != null) action!,
        ],
      ),
      const SizedBox(height: 4),
      Text(
        subtitle,
        style: const TextStyle(
          color: PeronaColors.muted,
          fontSize: 12,
          height: 1.5,
        ),
      ),
    ],
  );
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;
  const _Notice({required this.icon, required this.text, this.onTap});
  @override
  Widget build(BuildContext context) => Material(
    color: PeronaColors.lime,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: PeronaColors.forest),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: 12, height: 1.5),
              ),
            ),
            if (onTap != null) const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, description;
  final Widget? action;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });
  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            color: PeronaColors.background,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: PeronaColors.muted, size: 28),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: PeronaColors.muted,
            fontSize: 12,
            height: 1.6,
          ),
        ),
        if (action != null) ...[const SizedBox(height: 16), action!],
      ],
    ),
  );
}

class _Badge extends StatelessWidget {
  final String label;
  final bool warning;
  const _Badge({required this.label, this.warning = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: warning ? const Color(0xfffff0d8) : PeronaColors.lime,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: warning ? const Color(0xff83580d) : PeronaColors.forest,
      ),
    ),
  );
}

class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar({required this.name});
  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 21,
    backgroundColor: PeronaColors.lime,
    child: Text(
      name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase(),
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        color: PeronaColors.forest,
      ),
    ),
  );
}

class _PriceLabel extends StatelessWidget {
  final String label, value;
  const _PriceLabel({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 11, color: PeronaColors.muted),
      ),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
    ],
  );
}

class _OrderCard extends StatelessWidget {
  final Json order;
  final String? workerId;
  final VoidCallback onTap;
  const _OrderCard({required this.order, required this.onTap, this.workerId});
  @override
  Widget build(BuildContext context) {
    final items =
        ((order['items'] as List?) ?? [])
            .where((item) => workerId == null || item['worker_id'] == workerId)
            .toList();
    final statuses = items.map((item) => item['status'] as String).toSet();
    final remaining = money(order['total']) - paidTotal(order);
    final methods =
        ((order['payments'] as List?) ?? [])
            .where(
              (payment) =>
                  payment['voided_at'] == null && payment['method'] != null,
            )
            .map((payment) => payment['method'] as String)
            .toSet();
    final photoCount = ((order['order_photos'] as List?) ?? []).length;
    final wage = items.fold<int>(
      0,
      (sum, item) => sum + money(item['labor_fee']) * money(item['quantity']),
    );
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order['customer_name'] as String,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: PeronaColors.muted,
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                '#${order['number']}  ·  ${stamp(order['created_at'])} WIB',
                style: const TextStyle(fontSize: 11, color: PeronaColors.muted),
              ),
              const SizedBox(height: 12),
              Text(
                items
                    .map((item) => '${item['name']} × ${item['quantity']}')
                    .join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ...statuses.map(
                    (status) => _Badge(
                      label: status,
                      warning: ['Masuk', 'Dikerjakan'].contains(status),
                    ),
                  ),
                  _Badge(
                    label: remaining <= 0 ? 'Lunas' : 'Belum lunas',
                    warning: remaining > 0,
                  ),
                  ...methods.map((method) => _Badge(label: method)),
                  if (photoCount > 0) _Badge(label: '$photoCount foto'),
                ],
              ),
              const Divider(),
              Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  _PriceLabel(
                    label: workerId == null ? 'Tagihan' : 'Ongkos saya',
                    value: rp(workerId == null ? order['total'] : wage),
                  ),
                  _PriceLabel(
                    label: 'Sisa tagihan pelanggan',
                    value: rp(remaining),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Lihat detail order →',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: PeronaColors.forest,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

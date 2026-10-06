part of 'main.dart';

class OrderEditor extends StatefulWidget {
  final Repository repo;
  final List<Json> services, staff;
  final Json? existing;
  final ImagePicker? imagePicker;
  const OrderEditor({
    super.key,
    required this.repo,
    required this.services,
    required this.staff,
    this.existing,
    this.imagePicker,
  });
  @override
  State<OrderEditor> createState() => _OrderEditorState();
}

class _OrderEditorState extends State<OrderEditor> {
  final form = GlobalKey<FormState>();
  late TextEditingController customer, phone, notes, discount;
  late String id;
  late List<Json> items;
  late OrderSubmission submission;
  late DateTime orderAtWib;
  final photos = <PendingOrderPhoto>[];
  String payment = 'Belum lunas';
  String? saveFailure;
  bool busy = false, finishing = false;
  bool get editable => !busy && !submission.locked;

  @override
  void initState() {
    super.initState();
    final order = widget.existing ?? {};
    orderAtWib = jakarta(
      order['created_at'] == null
          ? DateTime.now()
          : DateTime.parse(order['created_at'] as String),
    );
    id = order['id'] as String? ?? const Uuid().v4();
    customer = TextEditingController(
      text: order['customer_name'] as String? ?? '',
    );
    phone = TextEditingController(text: order['phone'] as String? ?? '');
    notes = TextEditingController(text: order['notes'] as String? ?? '');
    discount = TextEditingController(text: '${order['discount'] ?? 0}');
    items =
        ((order['items'] as List?) ?? [])
            .map((item) => Json.from(item as Map))
            .toList();
    submission = OrderSubmission(widget.repo, isNew: widget.existing == null);
  }

  @override
  void dispose() {
    customer.dispose();
    phone.dispose();
    notes.dispose();
    discount.dispose();
    super.dispose();
  }

  Future<void> addItem() async {
    final selected = await showModalBottomSheet<Json>(
      context: context,
      isScrollControlled: true,
      builder:
          (_) => ServicePicker(services: widget.services, showWages: false),
    );
    if (selected == null || !mounted) return;
    final defaultWorker =
        widget.staff
            .where((person) => ['staff', 'technician'].contains(person['role']))
            .firstOrNull ??
        widget.staff.where((person) => person['role'] == 'owner').firstOrNull;
    setState(
      () => items.add({
        'id': const Uuid().v4(),
        'service_id': selected['id'],
        'name': selected['name'],
        'category': selected['category'],
        'price': selected['price'],
        'labor_fee': selected['labor_fee'],
        'quantity': 1,
        'worker_id':
            widget.repo.isAdmin
                ? (defaultWorker == null ? null : defaultWorker['id'])
                : widget.repo.userId,
        'status': 'Masuk',
      }),
    );
  }

  Future<void> chooseOrderDate() async {
    FocusScope.of(context).unfocus();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(orderAtWib.year, orderAtWib.month, orderAtWib.day),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Pilih tanggal order',
    );
    if (picked != null && mounted) {
      setState(
        () =>
            orderAtWib = DateTime.utc(
              picked.year,
              picked.month,
              picked.day,
              orderAtWib.hour,
              orderAtWib.minute,
              orderAtWib.second,
              orderAtWib.millisecond,
              orderAtWib.microsecond,
            ),
      );
    }
  }

  Future<void> chooseOrderTime() async {
    FocusScope.of(context).unfocus();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: orderAtWib.hour, minute: orderAtWib.minute),
      helpText: 'Jam order (WIB)',
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
    );
    if (picked != null && mounted) {
      setState(
        () =>
            orderAtWib = DateTime.utc(
              orderAtWib.year,
              orderAtWib.month,
              orderAtWib.day,
              picked.hour,
              picked.minute,
            ),
      );
    }
  }

  Future<void> pickPhoto(ImageSource source) async {
    setState(() => busy = true);
    try {
      final picked = await (widget.imagePicker ?? ImagePicker()).pickImage(
        source: source,
        maxWidth: 1400,
        maxHeight: 1400,
        imageQuality: 75,
      );
      if (picked == null) return;
      final extension = picked.name.split('.').last.toLowerCase();
      if (!['jpg', 'jpeg', 'png', 'webp'].contains(extension)) {
        throw ArgumentError('Pilih foto JPG, PNG, atau WebP.');
      }
      final bytes = await picked.readAsBytes();
      if (bytes.length > 2 * 1024 * 1024) {
        throw ArgumentError(
          'Foto maksimal 2 MB. Pilih foto dengan ukuran lebih kecil.',
        );
      }
      if (mounted) {
        setState(
          () =>
              photos.add(PendingOrderPhoto(bytes: bytes, extension: extension)),
        );
      }
    } catch (error) {
      if (mounted) message(context, errorText(error));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save({bool withReceipt = false}) async {
    if (busy) return;
    FocusScope.of(context).unfocus();
    if (!submission.locked) {
      if (customer.text.trim().isEmpty) {
        message(context, 'Isi nama pelanggan terlebih dahulu.');
        return;
      }
      if (int.tryParse(discount.text) == null) {
        message(context, 'Isi diskon dengan angka rupiah.');
        return;
      }
      if (!form.currentState!.validate()) return;
      if (items.isEmpty) {
        message(context, 'Tambahkan minimal satu layanan.');
        return;
      }
      try {
        Totals.fromItems(
          items,
          int.parse(discount.text),
          includeLabor: widget.repo.canViewWages,
        );
      } catch (error) {
        message(context, errorText(error));
        return;
      }
    }
    setState(() {
      busy = true;
      saveFailure = null;
    });
    try {
      await submission.submit(
        {
          'id': id,
          'version': widget.existing?['version'] ?? 0,
          'customer_name': customer.text.trim(),
          'created_at': jakartaToUtc(orderAtWib).toIso8601String(),
          'phone': phone.text.trim(),
          'notes': notes.text.trim(),
          'discount': int.parse(discount.text),
          'items': items,
        },
        paymentMethod: payment == 'Belum lunas' ? null : payment,
        photos: photos,
      );
      if (mounted && withReceipt) {
        // PDF failures are handled on their own page, after the complete save.
        // Retrying a receipt never submits a second order or payment.
        await openReceipt(context, widget.repo, id);
      }
      if (mounted) {
        setState(() {
          busy = false;
          finishing = true;
        });
        // PopScope must receive canPop=true before returning the saved order.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context, id);
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          saveFailure = errorText(error);
          busy = false;
        });
      }
    }
  }

  void openSavedDetail() {
    setState(() => finishing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context, id);
    });
  }

  Future<void> confirmLeave() async {
    if (busy || finishing) return;
    final leave = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Penyimpanan belum lengkap'),
            content: Text(
              submission.orderSaved
                  ? 'Order sudah tersimpan. Kamu bisa melengkapi pembayaran dan foto dari detail order.'
                  : 'Status penyimpanan belum dapat dipastikan. Coba lagi untuk memeriksa order yang sama.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Lanjutkan di sini'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  submission.orderSaved ? 'Buka detail' : 'Keluar dari form',
                ),
              ),
            ],
          ),
    );
    if (leave == true && mounted) {
      setState(() => finishing = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, submission.orderSaved ? id : null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Totals? total;
    try {
      total = Totals.fromItems(
        items,
        int.tryParse(discount.text) ?? -1,
        includeLabor: widget.repo.canViewWages,
      );
    } catch (_) {}
    return PopScope(
      canPop: finishing || (!busy && !submission.locked),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.existing == null ? 'Tambah order' : 'Edit order'),
        ),
        body: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              const _SectionTitle(
                title: 'Order pelanggan',
                subtitle:
                    'Isi layanan, pembayaran, dan foto barang dalam satu form.',
              ),
              const SizedBox(height: 20),
              AbsorbPointer(
                absorbing: !editable,
                child: Column(
                  children: [
                    _Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '1. Data pelanggan',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            key: const ValueKey('order-date-picker'),
                            onPressed: editable ? chooseOrderDate : null,
                            icon: const Icon(Icons.calendar_month_outlined),
                            label: Text(
                              'Tanggal order: ${DateFormat('dd/MM/yyyy').format(orderAtWib)}',
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            key: const ValueKey('order-time-picker'),
                            onPressed: editable ? chooseOrderTime : null,
                            icon: const Icon(Icons.schedule_outlined),
                            label: Text(
                              'Jam order: ${DateFormat('HH:mm').format(orderAtWib)} WIB',
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Pilih tanggal saat customer masuk, termasuk order lama yang belum dicatat. Rekap mengikuti tanggal ini.',
                            style: TextStyle(
                              fontSize: 12,
                              color: PeronaColors.muted,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: customer,
                            maxLength: 150,
                            decoration: const InputDecoration(
                              labelText: 'Nama pelanggan',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: requiredText,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: phone,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Nomor WhatsApp',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: notes,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Kondisi barang / catatan pengerjaan',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            '2. Layanan & penanggung jawab',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (items.isEmpty)
                            Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: Text(
                                'Pilih layanan untuk menghitung tagihan pelanggan.',
                                style: const TextStyle(
                                  color: PeronaColors.muted,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ...items.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: itemCard(item),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: editable ? addItem : null,
                            icon: const Icon(Icons.add),
                            label: const Text('Tambah layanan'),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: discount,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Diskon total (rupiah)',
                            ),
                            validator: nonNegative,
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (widget.existing == null) paymentPanel(total),
                    if (widget.existing != null)
                      const _Notice(
                        icon: Icons.payments_outlined,
                        text:
                            'Pembayaran yang sudah tercatat tetap tersimpan. Tambah atau koreksi pembayaran dari detail order.',
                      ),
                    const SizedBox(height: 20),
                    photoPanel(),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ringkasan tagihan',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      total == null
                          ? 'Periksa jumlah dan diskon'
                          : rp(total.revenue),
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: PeronaColors.forest,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Periksa tagihan sebelum menyimpan. Nota PDF bisa diunduh atau dikirim ke pelanggan.',
                      style: TextStyle(
                        fontSize: 12,
                        color: PeronaColors.muted,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (saveFailure != null) ...[
                const SizedBox(height: 16),
                _Notice(
                  icon: Icons.error_outline,
                  text:
                      '${submission.orderSaved ? 'Order sudah tersimpan; pembayaran atau foto belum lengkap. ' : ''}$saveFailure',
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: busy ? null : () => save(),
                icon:
                    busy
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.check_rounded),
                label: Text(
                  busy
                      ? 'Menyimpan order…'
                      : submission.locked
                      ? 'Coba simpan kembali'
                      : 'Simpan order',
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: busy ? null : () => save(withReceipt: true),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Simpan & buat nota PDF'),
              ),
              if (saveFailure != null && submission.orderSaved)
                TextButton(
                  onPressed: busy ? null : openSavedDetail,
                  child: const Text('Buka detail order yang tersimpan'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget paymentPanel(Totals? total) => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '3. Pembayaran awal',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'Pilih Tunai atau QRIS jika pembayaran sudah diterima.',
          style: TextStyle(
            fontSize: 12,
            color: PeronaColors.muted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final choice in ['Tunai', 'QRIS', 'Belum lunas'])
              ChoiceChip(
                showCheckmark: false,
                label: Text(choice),
                selected: payment == choice,
                avatar: Icon(switch (choice) {
                  'Tunai' => Icons.payments_outlined,
                  'QRIS' => Icons.qr_code_2,
                  _ => Icons.schedule,
                }, size: 18),
                onSelected:
                    editable ? (_) => setState(() => payment = choice) : null,
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          payment == 'Belum lunas'
              ? 'Belum ada pembayaran. Tagihan dapat dibayar bertahap dari detail order.'
              : 'Catat pelunasan $payment sebesar ${total == null ? 'nilai tagihan' : rp(total.revenue)} pada ${DateFormat('dd/MM/yyyy').format(orderAtWib)} (tanggal order).',
          style: const TextStyle(
            fontSize: 12,
            height: 1.5,
            color: PeronaColors.forest,
          ),
        ),
      ],
    ),
  );

  Widget photoPanel() => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Foto barang',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'Opsional · JPG, PNG, WebP · maksimal 2 MB per foto',
          style: TextStyle(
            fontSize: 12,
            height: 1.5,
            color: PeronaColors.muted,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: editable ? () => pickPhoto(ImageSource.camera) : null,
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Kamera'),
            ),
            OutlinedButton.icon(
              onPressed: editable ? () => pickPhoto(ImageSource.gallery) : null,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Galeri'),
            ),
          ],
        ),
        if (photos.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final photo in photos)
                SizedBox(
                  width: 112,
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          photo.bytes,
                          height: 96,
                          width: 112,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, _, _) => const SizedBox(
                                height: 96,
                                child: Icon(Icons.broken_image_outlined),
                              ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed:
                            editable
                                ? () => setState(() => photos.remove(photo))
                                : null,
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Hapus'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          Text(
            '${photos.length} foto akan disimpan bersama order.',
            style: const TextStyle(fontSize: 12, color: PeronaColors.forest),
          ),
        ],
        if (widget.existing != null &&
            ((widget.existing!['order_photos'] as List?) ?? []).isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              '${(widget.existing!['order_photos'] as List).length} foto sebelumnya tersedia di detail order.',
              style: const TextStyle(fontSize: 12, color: PeronaColors.muted),
            ),
          ),
      ],
    ),
  );

  Widget itemCard(Json item) {
    final workers =
        widget.staff
            .where(
              (person) =>
                  ['staff', 'owner', 'technician'].contains(person['role']) ||
                  person['id'] == item['worker_id'],
            )
            .toList();
    return Card(
      key: ValueKey(item['id']),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item['name'] as String,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  onPressed:
                      editable
                          ? () => setState(() => items.remove(item))
                          : null,
                  icon: const Icon(Icons.close),
                  tooltip: 'Hapus layanan',
                ),
              ],
            ),
            Text(
              '${rp(item['price'])} / unit',
              style: const TextStyle(fontSize: 12, color: PeronaColors.muted),
            ),
            const SizedBox(height: 14),
            TextFormField(
              initialValue: '${item['quantity']}',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Jumlah unit / pasang',
              ),
              validator:
                  (value) =>
                      (int.tryParse(value ?? '') ?? 0) >= 1 &&
                              (int.tryParse(value ?? '') ?? 0) <= 999
                          ? null
                          : 'Jumlah 1–999.',
              onChanged:
                  (value) => setState(
                    () => item['quantity'] = int.tryParse(value) ?? 0,
                  ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: item['worker_id'] as String?,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Penanggung jawab layanan',
              ),
              items:
                  workers
                      .map(
                        (person) => DropdownMenuItem(
                          value: person['id'] as String,
                          child: Text(
                            '${person['name']}${person['role'] == 'disabled' ? ' (nonaktif)' : ''}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
              onChanged:
                  editable
                      ? (value) => setState(() => item['worker_id'] = value)
                      : null,
              validator: requiredText,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: item['status'] as String,
              decoration: const InputDecoration(labelText: 'Status pengerjaan'),
              items:
                  ['Masuk', 'Dikerjakan', 'Selesai', 'Diambil']
                      .map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(status),
                        ),
                      )
                      .toList(),
              onChanged:
                  editable
                      ? (value) => setState(() => item['status'] = value)
                      : null,
            ),
          ],
        ),
      ),
    );
  }
}

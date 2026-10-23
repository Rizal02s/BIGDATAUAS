part of 'main.dart';

String _attendanceTime(DateTime? value) =>
    value == null
        ? '—'
        : '${DateFormat('dd/MM HH:mm').format(jakarta(value))} WIB';

class AttendancePage extends StatefulWidget {
  final Repository repo;
  final List<Json> staff;
  const AttendancePage({super.key, required this.repo, required this.staff});
  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  AttendanceToday? today;
  AttendanceReport? report;
  List<AttendanceEntry> rows = [];
  Period period = Period.forDate(jakarta(DateTime.now()), 'month');
  String? employee, todayFailure, reportFailure;
  bool loadingToday = true, loadingReport = true;
  int page = 0, request = 0, todayRequest = 0;
  final scroll = ScrollController();
  bool get owner => widget.repo.accessRole == 'owner';

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  Future<void> refreshToday() async {
    final token = ++todayRequest;
    setState(() {
      loadingToday = true;
      todayFailure = null;
    });
    try {
      final result = await widget.repo.attendanceToday();
      if (mounted && token == todayRequest) setState(() => today = result);
    } catch (e) {
      if (mounted && token == todayRequest) {
        setState(() => todayFailure = errorText(e));
      }
    } finally {
      if (mounted && token == todayRequest) {
        setState(() => loadingToday = false);
      }
    }
  }

  Future<void> loadReport({bool next = false}) async {
    if (!next && scroll.hasClients) scroll.jumpTo(0);
    final token = ++request;
    final target = next ? page + 1 : 0;
    setState(() {
      loadingReport = true;
      reportFailure = null;
      if (!next) {
        rows = [];
        report = null;
      }
    });
    try {
      final result = await widget.repo.attendanceReport(
        period,
        employee: employee,
        page: target,
      );
      if (!mounted || token != request) return;
      setState(() {
        report = result;
        page = target;
        rows =
            next
                ? {
                  for (final row in [...rows, ...result.rows]) row.id: row,
                }.values.toList()
                : result.rows;
      });
    } catch (e) {
      if (mounted && token == request) {
        setState(() => reportFailure = errorText(e));
      }
    } finally {
      if (mounted && token == request) setState(() => loadingReport = false);
    }
  }

  Future<void> refresh() async {
    await Future.wait([refreshToday(), loadReport()]);
  }

  Future<void> choosePeriod() async {
    final first = jakarta(period.start);
    final last = jakarta(period.end.subtract(const Duration(microseconds: 1)));
    final range = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: first, end: last),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Periode absensi (WIB), maksimal 366 hari',
      saveText: 'Pilih',
      confirmText: 'Pilih',
      cancelText: 'Batal',
    );
    if (range == null || !mounted) return;
    if (range.end.difference(range.start).inDays > 365) {
      message(context, 'Pilih periode maksimal 366 hari.');
      return;
    }
    period = Period.betweenDates(range.start, range.end);
    await loadReport();
  }

  Future<void> act(String action) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => _AttendanceActionDialog(
            repo: widget.repo,
            action: action,
            open: today?.open,
          ),
    );
    if (!mounted) return;
    await refresh();
    if (saved == true && mounted) message(context, 'Absensi tersimpan.');
  }

  Future<void> correct([AttendanceEntry? row]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => _AttendanceCorrectionDialog(
            repo: widget.repo,
            staff: widget.staff,
            existing: row,
          ),
    );
    if (!mounted) return;
    await refresh();
    if (saved == true && mounted) {
      message(context, 'Koreksi absensi tersimpan beserta alasannya.');
    }
  }

  Future<void> history(AttendanceEntry row) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _AttendanceHistory(repo: widget.repo, entry: row),
    );
  }

  Widget todayCard() => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Absensi saya',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (loadingToday)
          const LinearProgressIndicator()
        else if (todayFailure != null) ...[
          Text(
            todayFailure!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          TextButton(
            onPressed: refreshToday,
            child: const Text('Muat ulang absensi saya'),
          ),
        ] else if (today != null) ...[
          Text('${DateFormat('dd/MM/yyyy').format(today!.date)} · WIB'),
          Text(
            today!.today?.status ?? 'Belum ada catatan hari ini',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (today!.open != null) ...[
            const SizedBox(height: 8),
            Text('Masuk: ${_attendanceTime(today!.open!.checkIn)}'),
            if (today!.open!.data['business_date'] !=
                attendanceDate(today!.date))
              const Text(
                'Absen sebelumnya belum dipulangkan. Selesaikan atau minta koreksi owner.',
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const ValueKey('attendance-out'),
              onPressed: () => act('out'),
              icon: const Icon(Icons.logout),
              label: const Text('Absen pulang'),
            ),
          ] else if (today!.today == null) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const ValueKey('attendance-in'),
              onPressed: () => act('in'),
              icon: const Icon(Icons.login),
              label: const Text('Absen masuk'),
            ),
            Wrap(
              spacing: 12,
              children: [
                for (final status in ['Izin', 'Sakit'])
                  OutlinedButton(
                    key: ValueKey('attendance-$status'),
                    onPressed: () => act(status),
                    child: Text('Catat ${status.toLowerCase()}'),
                  ),
              ],
            ),
          ] else ...[
            if (today!.today!.checkIn != null)
              Text('Masuk: ${_attendanceTime(today!.today!.checkIn)}'),
            if (today!.today!.checkOut != null)
              Text('Pulang: ${_attendanceTime(today!.today!.checkOut)}'),
            if (today!.today!.notes.isNotEmpty) Text(today!.today!.notes),
          ],
          const SizedBox(height: 8),
          const Text(
            'Jam masuk/pulang dicatat server. Izin/sakit adalah catatan pegawai, tanpa alur persetujuan.',
          ),
        ],
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(owner ? 'Absensi pegawai' : 'Absensi saya'),
      actions: [
        IconButton(
          onPressed: loadingToday || loadingReport ? null : refresh,
          icon: const Icon(Icons.refresh),
          tooltip: 'Muat ulang',
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        controller: scroll,
        padding: const EdgeInsets.all(16),
        children: [
          todayCard(),
          const SizedBox(height: 20),
          Text(
            owner ? 'Rekap kehadiran tim' : 'Riwayat kehadiran saya',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey('attendance-period'),
            onPressed: loadingReport ? null : choosePeriod,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text('${periodLabel(period)} · WIB'),
          ),
          if (owner) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const ValueKey('attendance-employee'),
              initialValue: employee ?? '',
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Pegawai'),
              items: [
                const DropdownMenuItem(value: '', child: Text('Semua pegawai')),
                for (final person in widget.staff)
                  DropdownMenuItem(
                    value: person['id'] as String,
                    child: Text(
                      person['name'] as String,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged:
                  loadingReport
                      ? null
                      : (value) {
                        employee = value == '' ? null : value;
                        loadReport();
                      },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const ValueKey('add-attendance-correction'),
              onPressed: () => correct(),
              icon: const Icon(Icons.edit_calendar_outlined),
              label: const Text('Isi / koreksi absensi'),
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            'Tanggal awal dan akhir ikut dihitung. Durasi hanya dari catatan yang sudah pulang. Tanpa catatan tidak otomatis dianggap alpa. Ongkos tetap dihitung dari pekerjaan.',
          ),
          const SizedBox(height: 12),
          if (report != null) ...[
            _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${report!.present} hadir · ${report!.permission} izin · ${report!.sick} sakit',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Durasi tercatat: ${attendanceDuration(report!.minutes)}',
                  ),
                  Text('${report!.open} catatan belum pulang'),
                ],
              ),
            ),
            if (owner && report!.employees.isNotEmpty) ...[
              const SizedBox(height: 12),
              _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Per pegawai',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    for (final person in report!.employees)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              person['name'] as String,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${person['present']} hadir · ${person['permission']} izin · ${person['sick']} sakit',
                            ),
                            Text(
                              '${attendanceDuration(money(person['minutes']))} · ${person['open']} belum pulang',
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (rows.isEmpty)
              const Text('Belum ada catatan absensi pada periode ini.'),
            for (final row in rows)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${row.name} · ${row.status}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(DateFormat('dd/MM/yyyy').format(row.date)),
                      if (row.status == 'Hadir') ...[
                        Text('Masuk: ${_attendanceTime(row.checkIn)}'),
                        Text(
                          'Pulang: ${row.checkOut == null ? 'Belum tercatat' : _attendanceTime(row.checkOut)}',
                        ),
                      ],
                      if (row.notes.isNotEmpty) Text(row.notes),
                      if (row.reason.isNotEmpty)
                        Text('Koreksi owner: ${row.reason}'),
                      if (owner)
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton.icon(
                              key: ValueKey('correct-attendance-${row.id}'),
                              onPressed: () => correct(row),
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Koreksi'),
                            ),
                            TextButton.icon(
                              key: ValueKey('history-attendance-${row.id}'),
                              onPressed: () => history(row),
                              icon: const Icon(Icons.history),
                              label: const Text('Riwayat perubahan'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
          ],
          if (reportFailure != null) ...[
            Text(
              reportFailure!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            TextButton(
              onPressed: () => loadReport(next: report != null),
              child: const Text('Coba muat rekap lagi'),
            ),
          ],
          if (loadingReport)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (report?.hasMore == true && reportFailure == null)
            OutlinedButton(
              key: const ValueKey('attendance-next'),
              onPressed: () => loadReport(next: true),
              child: const Text('Muat catatan berikutnya'),
            ),
        ],
      ),
    ),
  );
}

class _AttendanceActionDialog extends StatefulWidget {
  final Repository repo;
  final String action;
  final AttendanceEntry? open;
  const _AttendanceActionDialog({
    required this.repo,
    required this.action,
    this.open,
  });
  @override
  State<_AttendanceActionDialog> createState() =>
      _AttendanceActionDialogState();
}

class _AttendanceActionDialogState extends State<_AttendanceActionDialog> {
  final form = GlobalKey<FormState>();
  final note = TextEditingController();
  final requestId = const Uuid().v4();
  bool busy = false;
  String? submitted, failure;
  bool get leave => ['Izin', 'Sakit'].contains(widget.action);
  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    submitted ??= note.text.trim();
    setState(() {
      busy = true;
      failure = null;
    });
    try {
      await widget.repo.recordAttendance(requestId, widget.action, submitted!);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => failure = errorText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      scrollable: true,
      title: Text(
        leave
            ? 'Catat ${widget.action.toLowerCase()}'
            : widget.action == 'in'
            ? 'Absen masuk?'
            : 'Absen pulang?',
      ),
      content: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              leave
                  ? 'Dicatat untuk hari ini menurut server (WIB). Isi keterangan yang dapat dibaca owner.'
                  : 'Jam dicatat otomatis oleh server saat disimpan.',
            ),
            if (widget.action == 'out' && widget.open != null)
              Text(
                'Untuk absen masuk ${_attendanceTime(widget.open!.checkIn)}.',
              ),
            if (leave) ...[
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('attendance-note'),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                controller: note,
                enabled: !busy && submitted == null,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Keterangan'),
                validator:
                    (v) =>
                        (v ?? '').trim().length < 5
                            ? 'Isi keterangan minimal 5 karakter.'
                            : null,
              ),
            ],
            if (failure != null)
              Text(
                failure!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
        FilledButton(
          key: const ValueKey('confirm-attendance'),
          onPressed: busy ? null : save,
          child: Text(
            busy
                ? 'Menyimpan…'
                : failure == null
                ? 'Simpan absensi'
                : 'Coba lagi',
          ),
        ),
      ],
    ),
  );
}

class _AttendanceCorrectionDialog extends StatefulWidget {
  final Repository repo;
  final List<Json> staff;
  final AttendanceEntry? existing;
  const _AttendanceCorrectionDialog({
    required this.repo,
    required this.staff,
    this.existing,
  });
  @override
  State<_AttendanceCorrectionDialog> createState() =>
      _AttendanceCorrectionDialogState();
}

class _AttendanceCorrectionDialogState
    extends State<_AttendanceCorrectionDialog> {
  final form = GlobalKey<FormState>();
  final note = TextEditingController(), reason = TextEditingController();
  late DateTime date;
  DateTime? entered, left;
  String? employee;
  String status = 'Hadir';
  bool busy = false;
  Json? submitted;
  String? failure;
  bool get editable => !busy && submitted == null;
  @override
  void initState() {
    super.initState();
    final row = widget.existing;
    date = row?.date ?? jakarta(DateTime.now());
    employee = row?.employeeId;
    status = row?.status ?? 'Hadir';
    entered = row?.checkIn == null ? null : jakarta(row!.checkIn!);
    left = row?.checkOut == null ? null : jakarta(row!.checkOut!);
    note.text = row?.notes ?? '';
  }

  @override
  void dispose() {
    note.dispose();
    reason.dispose();
    super.dispose();
  }

  Future<DateTime?> pickDate(DateTime initial, String help) => showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2020),
    lastDate: jakarta(DateTime.now()),
    helpText: help,
    cancelText: 'Batal',
    confirmText: 'Pilih',
  );
  Future<void> chooseDate() async {
    final selected = await pickDate(date, 'Tanggal absensi (WIB)');
    if (selected != null && mounted) {
      setState(() {
        date = selected;
        entered = null;
        left = null;
      });
    }
  }

  Future<void> chooseTime(bool incoming) async {
    DateTime? day = date;
    if (!incoming) {
      day = await pickDate(
        left ?? date,
        'Tanggal pulang (WIB), boleh hari berikutnya',
      );
    }
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        (incoming ? entered : left) ??
            DateTime(date.year, date.month, date.day, incoming ? 9 : 17),
      ),
      helpText: incoming ? 'Jam masuk (WIB)' : 'Jam pulang (WIB)',
    );
    if (time != null && mounted) {
      setState(() {
        final value = DateTime(
          day!.year,
          day.month,
          day.day,
          time.hour,
          time.minute,
        );
        if (incoming) {
          entered = value;
        } else {
          left = value;
        }
      });
    }
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    if (status == 'Hadir' && entered == null) {
      setState(() => failure = 'Pilih jam masuk.');
      return;
    }
    if (status == 'Hadir' &&
        left != null &&
        (left!.isBefore(entered!) ||
            left!.difference(entered!) > const Duration(hours: 48))) {
      setState(
        () => failure = 'Jam pulang harus setelah masuk, maksimal 48 jam.',
      );
      return;
    }
    submitted ??= {
      'p_employee': employee,
      'p_date': attendanceDate(date),
      'p_version': widget.existing?.version ?? 0,
      'p_status': status,
      'p_in':
          status == 'Hadir' ? jakartaToUtc(entered!).toIso8601String() : null,
      'p_out':
          status == 'Hadir' && left != null
              ? jakartaToUtc(left!).toIso8601String()
              : null,
      'p_notes': note.text.trim(),
      'p_reason': reason.text.trim(),
    };
    setState(() {
      busy = true;
      failure = null;
    });
    try {
      await widget.repo.correctAttendance(submitted!);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => failure = errorText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final people =
        widget.staff
            .where(
              (p) =>
                  p['id'] == employee ||
                  (p['deleted_at'] == null &&
                      [
                        'owner',
                        'admin',
                        'staff',
                        'technician',
                      ].contains(p['role'])),
            )
            .toList();
    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        scrollable: true,
        title: const Text('Koreksi absensi'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Khusus owner. Catatan dan alasan perubahan disimpan dalam riwayat. Untuk catatan yang sudah ada, buka tombol Koreksi pada barisnya.',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const ValueKey('correction-employee'),
                initialValue: employee,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Pegawai'),
                items: [
                  for (final p in people)
                    DropdownMenuItem(
                      value: p['id'] as String,
                      child: Text(
                        p['name'] as String,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged:
                    editable && widget.existing == null
                        ? (v) => setState(() => employee = v)
                        : null,
                validator: (v) => v == null ? 'Pilih pegawai.' : null,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed:
                    editable && widget.existing == null ? chooseDate : null,
                child: Text('${DateFormat('dd/MM/yyyy').format(date)} · WIB'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const ValueKey('correction-status'),
                initialValue: status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: [
                  for (final s in ['Hadir', 'Izin', 'Sakit'])
                    DropdownMenuItem(value: s, child: Text(s)),
                ],
                onChanged: editable ? (v) => setState(() => status = v!) : null,
              ),
              if (status == 'Hadir') ...[
                OutlinedButton(
                  key: const ValueKey('correction-in'),
                  onPressed: editable ? () => chooseTime(true) : null,
                  child: Text(
                    'Masuk: ${entered == null ? 'Pilih jam' : DateFormat('dd/MM HH:mm').format(entered!)} WIB',
                  ),
                ),
                OutlinedButton(
                  key: const ValueKey('correction-out'),
                  onPressed: editable ? () => chooseTime(false) : null,
                  child: Text(
                    'Pulang: ${left == null ? 'Belum pulang' : DateFormat('dd/MM HH:mm').format(left!)} WIB',
                  ),
                ),
                if (left != null)
                  TextButton(
                    onPressed:
                        editable ? () => setState(() => left = null) : null,
                    child: const Text('Kosongkan jam pulang'),
                  ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('correction-note'),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                controller: note,
                enabled: editable,
                maxLength: 500,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Keterangan'),
                validator:
                    (v) =>
                        status != 'Hadir' && (v ?? '').trim().length < 5
                            ? 'Isi keterangan minimal 5 karakter.'
                            : null,
              ),
              TextFormField(
                key: const ValueKey('correction-reason'),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                controller: reason,
                enabled: editable,
                maxLength: 500,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Alasan koreksi (wajib)',
                ),
                validator:
                    (v) =>
                        (v ?? '').trim().length < 5
                            ? 'Isi alasan minimal 5 karakter.'
                            : null,
              ),
              if (failure != null)
                Text(
                  failure!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
          FilledButton(
            key: const ValueKey('save-attendance-correction'),
            onPressed: busy ? null : save,
            child: Text(
              busy
                  ? 'Menyimpan…'
                  : submitted == null
                  ? 'Simpan koreksi'
                  : 'Coba lagi',
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceHistory extends StatefulWidget {
  final Repository repo;
  final AttendanceEntry entry;
  const _AttendanceHistory({required this.repo, required this.entry});
  @override
  State<_AttendanceHistory> createState() => _AttendanceHistoryState();
}

class _AttendanceHistoryState extends State<_AttendanceHistory> {
  late Future<List<Json>> future = widget.repo.attendanceHistory(
    widget.entry.id,
  );
  Widget snapshot(String label, dynamic data) {
    if (data == null) return Text('$label: belum ada catatan');
    final row = AttendanceEntry(Json.from(data as Map));
    return Text(
      '$label: ${row.status}\nMasuk ${_attendanceTime(row.checkIn)}\nPulang ${_attendanceTime(row.checkOut)}${row.notes.isEmpty ? '' : '\n${row.notes}'}',
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Riwayat perubahan'),
    content: SizedBox(
      width: 420,
      child: FutureBuilder<List<Json>>(
        future: future,
        builder: (context, state) {
          if (state.hasError) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(errorText(state.error!)),
                TextButton(
                  onPressed:
                      () => setState(
                        () =>
                            future = widget.repo.attendanceHistory(
                              widget.entry.id,
                            ),
                      ),
                  child: const Text('Coba lagi'),
                ),
              ],
            );
          }
          if (!state.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${widget.entry.name} · ${DateFormat('dd/MM/yyyy').format(widget.entry.date)}',
              ),
              if (state.data!.isEmpty)
                const Text('Belum ada riwayat perubahan.'),
              for (final event in state.data!) ...[
                const Divider(),
                Text(
                  '${event['actor_name']} · ${stamp(event['at'])} WIB',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  event['action'] == 'attendance.correct'
                      ? 'Koreksi owner'
                      : 'Catatan pegawai',
                ),
                snapshot('Sebelum', event['before']),
                const SizedBox(height: 8),
                snapshot('Sesudah', event['after']),
                if ((event['after'] as Map?)?['correction_reason'] != null &&
                    event['action'] == 'attendance.correct')
                  Text('Alasan: ${event['after']['correction_reason']}'),
              ],
            ],
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Tutup'),
      ),
    ],
  );
}

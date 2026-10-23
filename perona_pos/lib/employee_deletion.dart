part of 'main.dart';

Future<void> _showEmployeeDeletion(
  BuildContext context,
  Repository repo,
  Json person,
) async {
  await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _EmployeeDeletionDialog(repo: repo, person: person),
  );
}

class _EmployeeDeletionDialog extends StatefulWidget {
  final Repository repo;
  final Json person;
  const _EmployeeDeletionDialog({required this.repo, required this.person});
  @override
  State<_EmployeeDeletionDialog> createState() =>
      _EmployeeDeletionDialogState();
}

class _EmployeeDeletionDialogState extends State<_EmployeeDeletionDialog> {
  final form = GlobalKey<FormState>();
  late final TextEditingController reason;
  bool busy = false, attempted = false;
  String? failure;
  String? submitted;
  @override
  void initState() {
    super.initState();
    reason = TextEditingController(
      text: widget.person['delete_reason'] as String? ?? '',
    );
  }

  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  Future<void> remove() async {
    if (busy || !form.currentState!.validate()) return;
    submitted ??= reason.text.trim();
    setState(() {
      busy = true;
      attempted = true;
      failure = null;
    });
    try {
      await widget.repo.deleteEmployee(widget.person, submitted!);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => failure = errorText(error));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: Text(
        widget.person['deleted_at'] == null
            ? 'Hapus akun pegawai?'
            : 'Selesaikan penghapusan?',
      ),
      scrollable: true,
      content: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.person['name'] as String,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const Text(
              'Akun tidak dapat dipakai lagi dan penghapusan tidak bisa dibatalkan. Order, foto, pembayaran, dan riwayat ongkos tetap disimpan.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const ValueKey('employee-delete-reason'),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              controller: reason,
              enabled: !busy && submitted == null,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Alasan penghapusan',
                errorMaxLines: 2,
              ),
              validator:
                  (value) =>
                      (value?.trim().length ?? 0) < 5
                          ? 'Minimal 5 karakter.'
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
          onPressed: busy ? null : () => Navigator.pop(context, false),
          child: Text(attempted ? 'Tutup dan periksa daftar' : 'Batal'),
        ),
        FilledButton(
          key: const ValueKey('confirm-delete-employee'),
          onPressed: busy ? null : remove,
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Colors.white,
          ),
          child: Text(
            busy
                ? 'Menghapus…'
                : attempted
                ? 'Coba hapus lagi'
                : 'Hapus akun',
          ),
        ),
      ],
    ),
  );
}

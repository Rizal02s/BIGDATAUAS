import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perona_pos/app_theme.dart';
import 'package:perona_pos/domain.dart';
import 'package:perona_pos/main.dart';
import 'package:perona_pos/order_deadlines.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_page_test.dart'
    show capture, loadPreviewFonts, previewKey, pumpHome;
import 'order_detail_test.dart' show DetailRepository;
import 'order_editor_test.dart' show openEditor;
import 'order_submission_test.dart' show SubmissionRepository, draft;

class QueueRepository extends DetailRepository {
  final reads = <(DeadlineFilter, int, String?)>[];
  bool failQueue = false;
  bool many = false;
  @override
  Future<List<Json>> workQueue(
    DeadlineFilter filter,
    int page, {
    String? workerId,
  }) async {
    reads.add((filter, page, workerId));
    if (failQueue) {
      throw const PostgrestException(
        code: 'PGRST202',
        message: 'Missing work_queue',
      );
    }
    if (filter == DeadlineFilter.upcoming) return [];
    final base = await order('order-a');
    return List.generate(
      many && page == 0 ? 30 : 1,
      (i) => {
        ...base,
        'created_at': '2020-12-30T03:15:00Z',
        'id': 'queue-${page * 30 + i}',
        'number': page * 30 + i + 1,
        'customer_name': 'Pelanggan ${page * 30 + i + 1}',
        'due_date': '2021-01-01',
      },
    );
  }
}

Future<void> openQueue(
  WidgetTester tester,
  QueueRepository repo, {
  String? workerId,
  bool narrow = false,
}) async {
  tester.view.physicalSize = Size(narrow ? 320 : 412, 892);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    RepaintBoundary(
      key: previewKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: peronaTheme(),
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(narrow ? 1.5 : 1)),
              child: child!,
            ),
        home: WorkQueuePage(
          repo: repo,
          services: await repo.services(),
          staff: await repo.staff(),
          workerId: workerId,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadPreviewFonts);
  testWidgets(
    'Queue shows old overdue notes, changes filters, and empty state',
    (tester) async {
      final repo = QueueRepository();
      await openQueue(tester, repo);
      expect(find.textContaining('Terlambat'), findsWidgets);
      expect(find.text('Pelanggan 1'), findsOneWidget);
      await capture(tester, 'work-queue');
      await tester.tap(find.byType(DropdownButtonFormField<DeadlineFilter>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mendatang').last);
      await tester.pumpAndSettle();
      expect(repo.reads.last.$1, DeadlineFilter.upcoming);
      expect(
        find.text('Tidak ada pekerjaan pada pilihan ini.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Personal queue switches to team and supports more than 30 notes',
    (tester) async {
      final repo = QueueRepository()..many = true;
      await openQueue(tester, repo, workerId: 'staff-a');
      expect(repo.reads.last.$3, 'staff-a');
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(repo.reads.last.$3, null);
      await tester.scrollUntilVisible(
        find.text('Muat lebih banyak'),
        600,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Muat lebih banyak'));
      await tester.pumpAndSettle();
      expect(repo.reads.last.$2, 1);
      await tester.scrollUntilVisible(
        find.text('Pelanggan 31'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Pelanggan 31'), findsOneWidget);
    },
  );

  testWidgets(
    'Missing migration can retry, and 320px large text has no overflow',
    (tester) async {
      final repo = QueueRepository()..failQueue = true;
      await openQueue(tester, repo, narrow: true);
      expect(find.textContaining('009_order_deadlines.sql'), findsOneWidget);
      repo.failQueue = false;
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      expect(find.text('Pelanggan 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Owner admin technician can open queue from home without new bottom tab',
    (tester) async {
      for (final role in ['owner', 'admin', 'technician']) {
        final repo = QueueRepository();
        await pumpHome(tester, repo, role);
        final button = find.byKey(const ValueKey('open-work-queue'));
        await tester.scrollUntilVisible(
          button,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(repo.reads.single.$3, role == 'technician' ? 'staff-a' : null);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets('Edit preserves estimate and can clear it before saving', (
    tester,
  ) async {
    final repo = SubmissionRepository();
    final existing = {
      ...draft(),
      'version': 1,
      'created_at': '2026-10-03T03:15:00Z',
      'due_date': '2026-10-25',
      'items': [
        {
          'id': 'item-a',
          'service_id': 'service-a',
          'name': 'Deep Clean',
          'category': 'Sepatu',
          'price': 30000,
          'labor_fee': 10000,
          'quantity': 1,
          'worker_id': 'staff-a',
          'status': 'Masuk',
        },
      ],
    };
    await openEditor(tester, repo, existing: existing);
    final picker = find.byKey(const ValueKey('order-due-picker'));
    await tester.scrollUntilVisible(
      picker,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Estimasi: 25/10/2026'), findsOneWidget);
    await capture(tester, 'order-estimate');
    await tester.tap(find.byKey(const ValueKey('clear-order-due')));
    await tester.pumpAndSettle();
    expect(find.text('Pilih estimasi selesai'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Simpan order'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Simpan order'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan order'));
    await tester.pumpAndSettle();
    expect(repo.savedDraft!.containsKey('due_date'), true);
    expect(repo.savedDraft!['due_date'], null);
  });

  testWidgets('Calendar changes estimate without moving order date', (
    tester,
  ) async {
    final repo = SubmissionRepository();
    final existing = {
      ...draft(),
      'created_at': '2026-10-03T03:15:00Z',
      'due_date': '2026-10-25',
      'items': [
        {
          ...(await repo.services()).first,
          'id': 'item-a',
          'service_id': 'deep',
          'quantity': 1,
          'worker_id': repo.userId,
          'status': 'Masuk',
        },
      ],
    };
    await openEditor(tester, repo, existing: existing);
    final picker = find.byKey(const ValueKey('order-due-picker'));
    await tester.scrollUntilVisible(
      picker,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(picker);
    await tester.pumpAndSettle();
    await tester.tap(picker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('27').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Simpan order'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Simpan order'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan order'));
    await tester.pumpAndSettle();
    expect(repo.savedDraft!['due_date'], '2026-10-27');
    expect(
      DateTime.parse(repo.savedDraft!['created_at'] as String),
      DateTime.parse(existing['created_at'] as String),
    );
  });

  testWidgets(
    'Moving order date past estimate requires fixing estimate before save',
    (tester) async {
      final repo = SubmissionRepository();
      final existing = {
        ...draft(),
        'created_at': '2026-10-03T03:15:00Z',
        'due_date': '2026-10-25',
        'items': [
          {
            ...(await repo.services()).first,
            'id': 'item-a',
            'service_id': 'deep',
            'quantity': 1,
            'worker_id': repo.userId,
            'status': 'Masuk',
          },
        ],
      };
      await openEditor(tester, repo, existing: existing);
      await tester.tap(find.byKey(const ValueKey('order-date-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('26').last);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Simpan order'),
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Simpan order'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simpan order'));
      await tester.pumpAndSettle();
      expect(repo.savedDraft, isNull);
      expect(
        find.text('Estimasi selesai tidak boleh sebelum tanggal order.'),
        findsOneWidget,
      );
    },
  );
}

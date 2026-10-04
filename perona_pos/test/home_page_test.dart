import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perona_pos/app_theme.dart';
import 'package:perona_pos/domain.dart';
import 'package:perona_pos/main.dart';
import 'package:perona_pos/repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _TestSupabaseClient extends Fake implements SupabaseClient {
  @override
  Future<void> dispose() async {}
}

class DemoRepository extends Repository {
  DemoRepository() : super(_TestSupabaseClient()) {
    accessRole = 'staff';
  }
  final workerFilters = <String?>[];
  bool empty = false, fail = false;
  int reportReads = 0;

  @override
  String get userId => 'staff-a';

  @override
  Future<List<Json>> services() async => [
    {
      'id': 'service-a',
      'name': 'Deep Clean',
      'category': 'Sepatu',
      'price': 30000,
      'labor_fee': 10000,
      'active': true,
    },
  ];

  @override
  Future<List<Json>> staff() async => [
    {'id': 'owner-a', 'name': 'Rizal', 'role': 'owner'},
    {'id': 'staff-a', 'name': 'Dina', 'role': 'staff'},
    {'id': 'staff-b', 'name': 'Bagas', 'role': 'staff'},
    {'id': 'pending-a', 'name': 'Akun Baru', 'role': 'pending'},
  ];

  @override
  Future<Json> report(Period period) async {
    reportReads++;
    return empty
        ? {}
        : {
          'count': 12,
          'revenue': 540000,
          'cash': 420000,
          'labor': 125000,
          'discount': 15000,
          'outstanding_all': 180000,
          'wages': [
            {'id': 'staff-a', 'name': 'Dina', 'amount': 75000},
            {'id': 'staff-b', 'name': 'Bagas', 'amount': 50000},
          ],
        };
  }

  @override
  Future<List<Json>> orders(Period period, int page, {String? workerId}) async {
    workerFilters.add(workerId);
    if (fail) throw const AuthException('Koneksi pengujian terputus.');
    if (empty) return [];
    final orders = <Json>[
      {
        'id': 'order-a',
        'number': 24,
        'customer_name': 'Andi Pratama',
        'created_at': '2026-10-03T03:15:00Z',
        'total': 90000,
        'payments': [
          {'amount': 30000, 'voided_at': null},
        ],
        'items': [
          {
            'name': 'Deep Clean',
            'quantity': 2,
            'price': 30000,
            'labor_fee': 10000,
            'worker_id': 'staff-a',
            'status': 'Dikerjakan',
          },
          {
            'name': 'Fast Clean',
            'quantity': 1,
            'price': 30000,
            'labor_fee': 10000,
            'worker_id': 'staff-b',
            'status': 'Selesai',
          },
        ],
      },
      {
        'id': 'order-b',
        'number': 23,
        'customer_name': 'Sinta Dewi',
        'created_at': '2026-10-03T02:30:00Z',
        'total': 50000,
        'payments': [
          {'amount': 50000, 'voided_at': null},
        ],
        'items': [
          {
            'name': 'One Day Service',
            'quantity': 1,
            'price': 50000,
            'labor_fee': 20000,
            'worker_id': 'staff-b',
            'status': 'Selesai',
          },
        ],
      },
    ];
    return workerId == null
        ? orders
        : orders
            .where(
              (order) => (order['items'] as List).any(
                (item) => item['worker_id'] == workerId,
              ),
            )
            .toList();
  }
}

Future<void> loadPreviewFonts() async {
  if (!const bool.fromEnvironment('UI_PREVIEW')) return;
  var directory = File(Platform.resolvedExecutable).parent;
  while (directory.parent.path != directory.path) {
    final fonts = Directory(
      '${directory.path}/bin/cache/artifacts/material_fonts',
    );
    if (fonts.existsSync()) {
      final roboto = FontLoader('Roboto');
      for (final weight in ['regular', 'bold']) {
        final bytes =
            File('${fonts.path}/roboto-$weight.ttf').readAsBytesSync();
        roboto.addFont(Future.value(ByteData.sublistView(bytes)));
      }
      await roboto.load();
      final icons = FontLoader('MaterialIcons');
      icons.addFont(
        Future.value(
          ByteData.sublistView(
            File('${fonts.path}/materialicons-regular.otf').readAsBytesSync(),
          ),
        ),
      );
      await icons.load();
      return;
    }
    directory = directory.parent;
  }
  throw StateError('Flutter fonts not found for visual preview.');
}

const previewKey = ValueKey('home-preview');

Future<void> pumpHome(
  WidgetTester tester,
  DemoRepository repo,
  String role, {
  Size size = const Size(412, 892),
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
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
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
        home: HomePage(
          repo: repo,
          profile: {
            'id': role == 'owner' ? 'owner-a' : 'staff-a',
            'name': role == 'owner' ? 'Rizal' : 'Dina',
            'role': role,
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> capture(WidgetTester tester, String filename) async {
  if (!const bool.fromEnvironment('UI_PREVIEW')) return;
  final images = tester.widgetList<Image>(find.byType(Image)).toList();
  await tester.runAsync(() async {
    for (final widget in images) {
      await precacheImage(widget.image, tester.element(find.byKey(previewKey)));
    }
  });
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(previewKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('docs/ui/$filename.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(png!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(loadPreviewFonts);

  testWidgets('owner has finance dashboard and team management', (
    tester,
  ) async {
    final repo = DemoRepository();
    addTearDown(() => tester.runAsync(repo.db.dispose));
    await pumpHome(tester, repo, 'owner');
    expect(find.text('Portal Owner'), findsOneWidget);
    expect(find.text('Pembayaran masuk'), findsOneWidget);
    expect(find.text('Rp420.000'), findsOneWidget);
    expect(find.text('Pegawai'), findsOneWidget);
    expect(repo.workerFilters.last, isNull);
    await capture(tester, 'owner-home');
    await tester.tap(find.text('Pegawai'));
    await tester.pumpAndSettle();
    expect(find.text('Kelola pegawai'), findsOneWidget);
    expect(find.text('Menunggu aktivasi'), findsOneWidget);
    await capture(tester, 'owner-team');
  });

  testWidgets('technician sees finance and separate team and own wage page', (
    tester,
  ) async {
    final repo = DemoRepository();
    addTearDown(() => tester.runAsync(repo.db.dispose));
    await pumpHome(tester, repo, 'staff');
    expect(find.text('Portal Teknisi'), findsOneWidget);
    expect(find.text('Ongkos kerja saya'), findsNothing);
    expect(find.text('Pembayaran masuk'), findsOneWidget);
    expect(find.text('Pegawai'), findsNothing);
    expect(repo.workerFilters.last, isNull);
    await capture(tester, 'staff-home');
    await tester.tap(find.text('Ongkos'));
    await tester.pumpAndSettle();
    expect(find.text('Ongkos pegawai'), findsOneWidget);
    expect(find.text('Rp75.000'), findsWidgets);
    expect(find.text('Rp125.000'), findsOneWidget);
    await capture(tester, 'technician-wages');
    await tester.tap(find.text('Order'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Andi Pratama'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Andi Pratama'), findsOneWidget);
    expect(find.text('Sinta Dewi'), findsNothing);
    expect(find.text('Rp90.000'), findsOneWidget);
    expect(find.text('Fast Clean × 1'), findsNothing);
    await capture(tester, 'staff-work');
  });

  testWidgets('technician can switch all orders and return to shared summary', (
    tester,
  ) async {
    final repo = DemoRepository();
    addTearDown(() => tester.runAsync(repo.db.dispose));
    await pumpHome(tester, repo, 'staff');
    await tester.tap(find.text('Order'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Semua order'));
    await tester.pumpAndSettle();
    expect(repo.workerFilters.last, isNull);
    await tester.tap(find.text('Ringkasan'));
    await tester.pumpAndSettle();
    expect(repo.workerFilters.last, isNull);
    expect(find.text('Pembayaran masuk'), findsOneWidget);
  });

  testWidgets('staff catalog has no price edit or account management actions', (
    tester,
  ) async {
    final repo = DemoRepository();
    addTearDown(() => tester.runAsync(repo.db.dispose));
    await pumpHome(tester, repo, 'staff');
    await tester.tap(find.text('Layanan'));
    await tester.pumpAndSettle();
    expect(find.text('Daftar layanan'), findsOneWidget);
    expect(find.text('Tambah layanan'), findsNothing);
    expect(find.byTooltip('Edit layanan'), findsNothing);
    expect(find.text('Pegawai'), findsNothing);
  });

  testWidgets('small phone and enlarged text can scroll without overflow', (
    tester,
  ) async {
    final repo = DemoRepository();
    addTearDown(() => tester.runAsync(repo.db.dispose));
    for (final role in ['owner', 'staff', 'technician', 'admin']) {
      await pumpHome(
        tester,
        repo,
        role,
        size: const Size(360, 800),
        textScale: 1.5,
      );
      expect(tester.takeException(), isNull);
      for (var i = 0; i < 7; i++) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -350));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('empty personal work and loading error explain next action', (
    tester,
  ) async {
    final repo = DemoRepository()..empty = true;
    addTearDown(() => tester.runAsync(repo.db.dispose));
    await pumpHome(tester, repo, 'staff');
    await tester.tap(find.text('Order'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Belum ada pekerjaan untukmu'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Belum ada pekerjaan untukmu'), findsOneWidget);
    repo.fail = true;
    await tester.tap(find.byTooltip('Muat ulang'));
    await tester.pumpAndSettle();
    expect(find.text('Data belum bisa dimuat'), findsOneWidget);
    repo.fail = false;
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.text('Daftar order'), findsOneWidget);
  });

  testWidgets(
    'owner wage page is separate and account menu offers admin and technician',
    (tester) async {
      final repo = DemoRepository();
      await pumpHome(tester, repo, 'owner');
      expect(find.text('Ongkos kerja tim'), findsNothing);
      await tester.tap(find.text('Ongkos'));
      await tester.pumpAndSettle();
      expect(find.text('Ongkos pegawai'), findsOneWidget);
      await capture(tester, 'owner-wages');
      await tester.tap(find.text('Pegawai'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Atur akses').first);
      await tester.pumpAndSettle();
      expect(find.text('Aktifkan sebagai admin'), findsOneWidget);
      expect(find.text('Aktifkan sebagai teknisi'), findsOneWidget);
    },
  );

  testWidgets(
    'admin has only operational pages and never requests wage reports',
    (tester) async {
      final repo = DemoRepository();
      await pumpHome(tester, repo, 'admin');
      expect(find.text('Portal Admin'), findsOneWidget);
      expect(find.text('Ongkos'), findsNothing);
      expect(find.text('Pegawai'), findsNothing);
      expect(find.text('Layanan'), findsNothing);
      expect(find.text('Pembayaran masuk'), findsNothing);
      expect(repo.reportReads, 0);
      expect(repo.workerFilters.last, isNull);
      await capture(tester, 'admin-home');
      await tester.tap(find.text('Order'));
      await tester.pumpAndSettle();
      expect(find.text('Pekerjaan saya'), findsNothing);
      expect(repo.reportReads, 0);
    },
  );
}

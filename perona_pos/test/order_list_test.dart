import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perona_pos/domain.dart';

import 'home_page_test.dart'
    show DemoRepository, pumpHome, capture, loadPreviewFonts;

class OrderListRepository extends DemoRepository {
  bool longName = false;

  @override
  Future<List<Json>> orders(
    Period period,
    int page, {
    String? workerId,
  }) async => [
    {
      'id': 'mixed',
      'number': 7,
      'customer_name':
          longName
              ? 'Mario Pelanggan Perona dengan Nama yang Sangat Panjang'
              : 'Mario',
      'created_at': '2026-10-16T17:30:00Z',
      'total': 105000,
      'items': [
        {'name': 'Tas / Bag (Small)', 'quantity': 1, 'status': 'Masuk'},
        {'name': 'Sandal / Topi / Cap', 'quantity': 1, 'status': 'Selesai'},
      ],
      'payments': [
        {'amount': 105000, 'method': 'QRIS', 'voided_at': null},
      ],
      'order_photos': [
        {'id': 'photo-a'},
      ],
    },
    {
      'id': 'ready',
      'number': 8,
      'customer_name': 'Sinta',
      'created_at': '2026-10-17T03:00:00Z',
      'total': 90000,
      'items': [
        {'name': 'Deep Clean', 'quantity': 1, 'status': 'Selesai'},
        {'name': 'Fast Clean', 'quantity': 1, 'status': 'Diambil'},
      ],
      'payments': [
        {'amount': 30000, 'method': 'Tunai', 'voided_at': null},
        {
          'amount': 60000,
          'method': 'QRIS',
          'voided_at': '2026-10-17T04:00:00Z',
        },
      ],
    },
    {
      'id': 'picked',
      'number': 9,
      'customer_name': 'Andi',
      'created_at': '2026-10-17T04:00:00Z',
      'total': 60000,
      'items': [
        {'name': 'Deep Clean', 'quantity': 2, 'status': 'Diambil'},
      ],
      'payments': [],
    },
    {
      'id': 'new',
      'number': 10,
      'customer_name': 'Dina',
      'created_at': '2026-10-17T05:00:00Z',
      'total': 30000,
      'items': [
        {'name': 'Deep Clean', 'quantity': 1, 'status': 'Masuk'},
      ],
      'payments': [],
    },
  ];
}

void main() {
  setUpAll(loadPreviewFonts);

  testWidgets('order list summarizes mixed progress and effective payments', (
    tester,
  ) async {
    final repo = OrderListRepository();
    await pumpHome(tester, repo, 'owner');
    await tester.tap(find.text('Order'));
    await tester.pumpAndSettle();
    for (final expected in [
      ('mixed', 'Mario', 'Rp105.000', 'Dikerjakan', 'Lunas'),
      ('ready', 'Sinta', 'Rp90.000', 'Selesai', 'DP'),
      ('picked', 'Andi', 'Rp60.000', 'Diambil', 'Belum bayar'),
      ('new', 'Dina', 'Rp30.000', 'Masuk', 'Belum bayar'),
    ]) {
      final card = find.byKey(ValueKey('order-card-${expected.$1}'));
      await tester.scrollUntilVisible(
        card,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      for (final text in [
        '17/10/2026',
        expected.$2,
        expected.$3,
        expected.$4,
        expected.$5,
      ]) {
        expect(
          find.descendant(of: card, matching: find.text(text)),
          findsOneWidget,
        );
      }
      expect(
        find.descendant(of: card, matching: find.textContaining('QRIS')),
        findsNothing,
      );
      expect(
        find.descendant(of: card, matching: find.textContaining('foto')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: card,
          matching: find.textContaining('Sisa tagihan'),
        ),
        findsNothing,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact order list preview and narrow screen with large text', (
    tester,
  ) async {
    final repo = OrderListRepository();
    await pumpHome(tester, repo, 'owner');
    await tester.tap(find.text('Order'));
    await tester.pumpAndSettle();
    await capture(tester, 'order-list-simple');
    await tester.pumpWidget(const SizedBox.shrink());
    repo.longName = true;
    await pumpHome(
      tester,
      repo,
      'owner',
      size: const Size(320, 740),
      textScale: 1.5,
    );
    await tester.tap(find.text('Order'));
    await tester.pumpAndSettle();
    for (final id in ['mixed', 'ready', 'picked', 'new']) {
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('order-card-$id')),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
    }
  });
}

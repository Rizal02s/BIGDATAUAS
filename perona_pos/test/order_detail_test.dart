import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perona_pos/domain.dart';

import 'home_page_test.dart' show DemoRepository, pumpHome;

class DetailRepository extends DemoRepository {
  final photoReads = <String>[];
  @override
  Future<List<Json>> orders(Period period, int page, {String? workerId}) async {
    final result = await super.orders(period, page, workerId: workerId);
    return result
        .map(
          (order) => {
            ...order,
            'notes': 'Sepatu putih, noda di bagian depan.',
            'phone': '081234567890',
            'discount': 0,
            'labor_total': 30000,
            'payments': [
              {
                'id': 'payment-a',
                'amount': order['total'],
                'method': 'QRIS',
                'paid_at': order['created_at'],
                'voided_at': null,
              },
            ],
            'order_photos': [
              {'id': 'photo-a', 'path': 'order-a/staff-a/photo-a.png'},
            ],
          },
        )
        .toList();
  }

  @override
  Future<Json> order(String id) async => (await orders(
    Period.forDate(DateTime(2026, 10, 3), 'day'),
    0,
  )).firstWhere((order) => order['id'] == id);

  @override
  Future<String> photoUrl(String path) async {
    photoReads.add(path);
    return 'https://example.supabase.co/test-photo.png';
  }
}

void main() {
  testWidgets('recap opens service, QRIS payment, and saved photo details', (
    tester,
  ) async {
    final repo = DetailRepository();
    await pumpHome(tester, repo, 'owner');
    await tester.scrollUntilVisible(
      find.text('Andi Pratama'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('1 foto'), findsWidgets);
    await tester.tap(find.text('Andi Pratama'));
    await tester.pumpAndSettle();
    expect(find.text('Detail order'), findsOneWidget);
    expect(find.text('Lunas · QRIS'), findsOneWidget);
    expect(
      find.text('Catatan: Sepatu putih, noda di bagian depan.'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Foto barang'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -350));
    await tester.pumpAndSettle();
    expect(repo.photoReads, ['order-a/staff-a/photo-a.png']);
    expect(find.text('Galeri'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

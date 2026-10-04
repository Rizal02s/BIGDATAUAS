import 'package:flutter_test/flutter_test.dart';
import 'package:perona_pos/domain.dart';
import 'package:perona_pos/report_data.dart';

import 'home_page_test.dart' show DemoRepository;

Json sampleOrder({int index = 1, String? createdAt, String? phone}) => {
  'id': 'order-$index',
  'number': index,
  'customer_name': 'Customer $index',
  'phone': phone ?? '08123456$index',
  'created_at': createdAt ?? '2026-10-03T03:15:00Z',
  'discount': 5000,
  'total': 85000,
  'labor_total': 30000,
  'items': [
    {
      'name': 'Deep Clean',
      'price': 30000,
      'labor_fee': 10000,
      'quantity': 2,
      'worker_id': 'staff-a',
      'status': 'Selesai',
    },
    {
      'name': 'Perawatan sepatu kulit',
      'price': 30000,
      'labor_fee': 10000,
      'quantity': 1,
      'worker_id': 'staff-b',
      'status': 'Masuk',
    },
  ],
  'payments': [
    {'amount': 30000, 'method': 'QRIS', 'voided_at': null},
    {'amount': 85000, 'method': 'Tunai', 'voided_at': '2026-10-03T04:00:00Z'},
  ],
};

class PagedRepository extends DemoRepository {
  final pages = <int>[];
  @override
  Future<List<Json>> orders(Period period, int page, {String? workerId}) async {
    pages.add(page);
    workerFilters.add(workerId);
    return List.generate(
      61,
      (i) => sampleOrder(index: i),
    ).skip(page * 30).take(30).toList();
  }
}

void main() {
  final period = Period.forDate(DateTime(2026, 10, 1), 'month');
  test('export reads every page and preserves worker filter', () async {
    final repo = PagedRepository();
    final rows = await repo.allOrders(period, workerId: 'staff-a');
    expect(rows.length, 61);
    expect(repo.pages, [0, 1, 2]);
    expect(repo.workerFilters, ['staff-a', 'staff-a', 'staff-a']);
    expect(rows.last['id'], 'order-60');
  });
  test('period exports use WIB boundaries and exclude deleted orders', () {
    final rows = reportOrders([
      sampleOrder(index: 1, createdAt: '2026-09-30T17:00:00Z'),
      sampleOrder(index: 2, createdAt: '2026-09-30T16:59:59Z'),
      sampleOrder(index: 3, createdAt: '2026-10-31T17:00:00Z'),
      {...sampleOrder(index: 4), 'deleted_at': '2026-10-04T00:00:00Z'},
      sampleOrder(index: 5, createdAt: '2026-10-31T16:59:59Z'),
    ], period);
    expect(rows.map((o) => o['id']), ['order-1', 'order-5']);
    expect(periodLabel(period), 'Oktober 2026');
  });
  test('worker wages include only assigned items and multiply quantity', () {
    final report = WorkerReport([sampleOrder()], 'staff-a');
    expect(report.entries.length, 1);
    expect(report.quantity, 2);
    expect(report.completed, 2);
    expect(report.orderCount, 1);
    expect(report.total, 20000);
  });
  test('unpaid counts deduplicate customers and ignore voided payments', () {
    final report = OrderReport([
      sampleOrder(index: 1, phone: '0812 345'),
      sampleOrder(index: 2, phone: '+62 812345'),
      {
        ...sampleOrder(index: 3),
        'payments': [
          {'amount': 85000, 'method': 'Tunai', 'voided_at': null},
        ],
      },
    ], includeWages: true);
    expect(report.revenue, 255000);
    expect(report.discount, 15000);
    expect(report.labor, 90000);
    expect(report.paid, 145000);
    expect(report.remaining, 110000);
    expect(report.unpaidCount, 2);
    expect(report.unpaidCustomers, 1);
    expect(report.quantity, 9);
  });
  test('admin summary contains no labor value even if input includes it', () {
    expect(OrderReport([sampleOrder()], includeWages: false).labor, 0);
  });
  test('receipt keeps only customer fields and effective payments', () {
    final receipt = CustomerReceipt.fromOrder(sampleOrder());
    expect(receipt.total, 85000);
    expect(receipt.paid, 30000);
    expect(receipt.remaining, 55000);
    expect(receipt.methods, ['QRIS']);
    expect(receipt.lines.first.price, 30000);
    expect(receipt.lines.first.quantity, 2);
  });
}

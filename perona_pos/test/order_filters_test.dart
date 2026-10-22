import 'package:flutter_test/flutter_test.dart';
import 'package:perona_pos/domain.dart';
import 'package:perona_pos/order_filters.dart';

Json order({
  String id = 'a',
  int number = 24,
  String name = 'Nadia Putri',
  String phone = '+62 812-3456-7890',
  List<String> statuses = const ['Masuk'],
  int paid = 0,
  int total = 100000,
}) => {
  'id': id,
  'number': number,
  'customer_name': name,
  'phone': phone,
  'created_at': '2026-10-03T03:00:00Z',
  'total': total,
  'items': [
    for (var i = 0; i < statuses.length; i++)
      {'status': statuses[i], 'worker_id': i == 0 ? 'worker-a' : 'worker-b'},
  ],
  'payments': [
    {'amount': paid, 'voided_at': null},
    {'amount': 999999, 'voided_at': '2026-10-03T04:00:00Z'},
  ],
};

void main() {
  test(
    'search accepts partial case-insensitive names, normalized phones and receipt numbers',
    () {
      final row = order();
      for (final query in [
        'nadia',
        '  NADIA   putri ',
        'putri',
        '0812 3456',
        '+628123456',
        '8123456',
        '00628123456',
        '3456-7890',
        '#24',
        'nota #24',
        '24',
        '00024',
      ]) {
        expect(OrderFilter(query: query).matches(row), isTrue, reason: query);
      }
      for (final query in [
        'Rizky',
        '081299999',
        '#99',
        'Nadia 999',
        '%',
        '_',
      ]) {
        expect(OrderFilter(query: query).matches(row), isFalse, reason: query);
      }
      expect(const OrderFilter(query: '  ').active, isFalse);
    },
  );

  test(
    'work filters use the same summary as cards and unfinished mixes stay in progress',
    () {
      for (final sample in [
        (['Masuk', 'Masuk'], WorkFilter.newOrder),
        (['Masuk', 'Selesai'], WorkFilter.inProgress),
        (['Dikerjakan'], WorkFilter.inProgress),
        (['Selesai', 'Diambil'], WorkFilter.ready),
        (['Diambil', 'Diambil'], WorkFilter.pickedUp),
      ]) {
        final row = order(statuses: sample.$1);
        for (final work in WorkFilter.values.where(
          (f) => ![WorkFilter.all, WorkFilter.notPickedUp].contains(f),
        )) {
          expect(
            OrderFilter(work: work).matches(row),
            work == sample.$2,
            reason: '${sample.$1} / $work',
          );
        }
        expect(
          const OrderFilter(work: WorkFilter.notPickedUp).matches(row),
          sample.$2 != WorkFilter.pickedUp,
        );
      }
      expect(
        const OrderFilter(
          work: WorkFilter.notPickedUp,
        ).matches(order(statuses: [])),
        isFalse,
      );
    },
  );

  test(
    'payment filters ignore voided payments and outstanding includes DP',
    () {
      final unpaid = order();
      final deposit = order(paid: 30000);
      final paid = order(paid: 100000);
      expect(
        const OrderFilter(payment: PaymentFilter.outstanding).matches(unpaid),
        isTrue,
      );
      expect(
        const OrderFilter(payment: PaymentFilter.outstanding).matches(deposit),
        isTrue,
      );
      expect(
        const OrderFilter(payment: PaymentFilter.outstanding).matches(paid),
        isFalse,
      );
      expect(
        const OrderFilter(payment: PaymentFilter.unpaid).matches(deposit),
        isFalse,
      );
      expect(
        const OrderFilter(payment: PaymentFilter.deposit).matches(deposit),
        isTrue,
      );
      expect(
        const OrderFilter(payment: PaymentFilter.paid).matches(paid),
        isTrue,
      );
      expect(
        const OrderFilter(payment: PaymentFilter.paid).matches(order(total: 0)),
        isTrue,
      );
    },
  );

  test(
    'query work and payment combine while personal work uses only assigned services',
    () {
      final row = order(statuses: ['Selesai', 'Masuk'], paid: 25000);
      const filter = OrderFilter(
        query: 'nadia',
        work: WorkFilter.ready,
        payment: PaymentFilter.deposit,
      );
      expect(filter.matches(row), isFalse);
      expect(filter.matches(row, workerId: 'worker-a'), isTrue);
      expect(filter.matches(row, workerId: 'worker-b'), isFalse);
      expect(const OrderFilter().matches(row, workerId: 'other'), isFalse);
      expect(
        filter
            .copyWith(payment: PaymentFilter.paid)
            .matches(row, workerId: 'worker-a'),
        isFalse,
      );
    },
  );

  test(
    'results exclude removed and out-of-period orders and sort newest first',
    () {
      final period = Period.forDate(DateTime(2026, 10, 3), 'day');
      final rows = [
        order(id: 'a'),
        {...order(id: 'b'), 'created_at': '2026-10-03T05:00:00Z'},
        {...order(id: 'removed'), 'deleted_at': '2026-10-03T05:00:00Z'},
        {
          ...order(id: 'before'),
          'created_at':
              period.start
                  .subtract(const Duration(seconds: 1))
                  .toIso8601String(),
        },
        {...order(id: 'after'), 'created_at': period.end.toIso8601String()},
      ];
      expect(
        const OrderFilter(
          query: 'nadia',
        ).apply(rows, period).map((r) => r['id']),
        ['b', 'a'],
      );
    },
  );
}

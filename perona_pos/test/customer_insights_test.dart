import 'package:flutter_test/flutter_test.dart';
import 'package:perona_pos/customer_insights.dart';
import 'package:perona_pos/domain.dart';

Json receipt(
  String id,
  String name,
  String phone,
  String at, {
  int total = 50000,
}) => {
  'id': id,
  'customer_name': name,
  'phone': phone,
  'created_at': at,
  'total': total,
  'items': [
    {'name': 'Deep Clean', 'quantity': 8},
    {'name': 'Repaint', 'quantity': 2},
  ],
};

void main() {
  final period = Period.betweenDates(
    DateTime(2026, 10, 1),
    DateTime(2026, 10, 3),
  );

  test(
    'inclusive WIB range includes both entire dates and supports one day',
    () {
      expect(period.start, DateTime.utc(2026, 9, 30, 17));
      expect(period.end, DateTime.utc(2026, 10, 3, 17));
      expect(period.contains(DateTime.utc(2026, 9, 30, 17)), isTrue);
      expect(
        period.contains(DateTime.utc(2026, 10, 3, 16, 59, 59, 999)),
        isTrue,
      );
      expect(period.contains(period.end), isFalse);
      final day = Period.betweenDates(
        DateTime(2026, 12, 31, 12),
        DateTime(2026, 12, 31),
      );
      expect(day.end.difference(day.start), const Duration(days: 1));
      expect(day.end, DateTime.utc(2026, 12, 31, 17));
      expect(
        () => Period.betweenDates(DateTime(2026, 10, 3), DateTime(2026, 10, 1)),
        throwsArgumentError,
      );
    },
  );

  test(
    'phone variants group names and unique receipts count once regardless of quantity',
    () {
      final first = receipt('1', 'Nadia', '0812-3456', '2026-10-01T01:00:00Z');
      final ranking = CustomerRanking([
        first,
        first,
        receipt(
          '2',
          'Nadia Putri',
          '+62 812 3456',
          '2026-10-02T01:00:00Z',
          total: 80000,
        ),
        receipt('3', 'Nadia P', '00628123456', '2026-10-03T01:00:00Z'),
        receipt('4', 'Nadia P', '8123456', '2026-10-03T02:00:00Z'),
      ], period);
      final customer = ranking.customers.single;
      expect(customer.visits, 4);
      expect(customer.total, 230000);
      expect(customer.name, 'Nadia P');
      expect(customer.orders.map((o) => o['id']), ['4', '3', '2', '1']);
    },
  );

  test(
    'fallback names normalize spaces and case, different phone numbers stay separate',
    () {
      final ranking = CustomerRanking([
        receipt('1', '  Ayu   Putri ', '', '2026-10-01T01:00:00Z'),
        receipt('2', 'ayu putri', '', '2026-10-02T01:00:00Z'),
        receipt('3', 'Ayu Putri', '08120001', '2026-10-01T01:00:00Z'),
        receipt('4', 'Ayu Putri', '08120002', '2026-10-01T01:00:00Z'),
      ], period);
      expect(ranking.customers, hasLength(3));
      expect(ranking.customers.first.visits, 2);
      expect(
        ranking
            .find(customerIdentity(ranking.customers.first.orders.first))
            ?.visits,
        2,
      );
      expect(ranking.find('missing'), isNull);
    },
  );

  test(
    'ranking uses visits then latest visit and excludes removed or out-of-range notes',
    () {
      final ranking = CustomerRanking([
        receipt('1', 'Frequent', '', '2026-10-01T01:00:00Z'),
        receipt('2', 'Frequent', '', '2026-10-01T02:00:00Z'),
        receipt('3', 'Latest', '', '2026-10-03T16:59:59Z'),
        receipt('4', 'Earlier', '', '2026-09-30T17:00:00Z'),
        receipt('5', 'Outside', '', '2026-09-30T16:59:59Z'),
        receipt('6', 'Outside', '', '2026-10-03T17:00:00Z'),
        {
          ...receipt('7', 'Deleted', '', '2026-10-02T01:00:00Z'),
          'deleted_at': '2026-10-02T02:00:00Z',
        },
      ], period);
      expect(ranking.customers.map((c) => c.name), [
        'Frequent',
        'Latest',
        'Earlier',
      ]);
      expect(CustomerRanking([], period).customers, isEmpty);
    },
  );
}

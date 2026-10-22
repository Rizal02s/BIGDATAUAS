import 'domain.dart';
import 'report_data.dart';

/// Phone numbers identify customers; names are used only without a number.
String customerIdentity(Json order) {
  final phone = (order['phone'] as String? ?? '').replaceAll(RegExp(r'\D'), '');
  if (phone.isEmpty) {
    final name = (order['customer_name'] as String)
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
    return 'name:$name';
  }
  final international = phone.startsWith('00') ? phone.substring(2) : phone;
  final normalized =
      international.startsWith('0')
          ? '62${international.substring(1)}'
          : international.startsWith('8')
          ? '62$international'
          : international;
  return 'phone:$normalized';
}

class CustomerVisits {
  final String identity;

  /// Newest first. One unique receipt counts as one visit.
  final List<Json> orders;
  const CustomerVisits(this.identity, this.orders);
  String get name => (orders.first['customer_name'] as String).trim();
  String get phone => orders.first['phone'] as String? ?? '';
  int get visits => orders.length;
  int get total => orders.fold(0, (sum, order) => sum + money(order['total']));
  DateTime get lastVisit =>
      DateTime.parse(orders.first['created_at'] as String);
}

class CustomerRanking {
  final Period period;
  final List<CustomerVisits> customers;
  CustomerRanking(List<Json> rows, this.period)
    : customers = _rank(rows, period);

  CustomerVisits? find(String identity) {
    for (final customer in customers) {
      if (customer.identity == identity) return customer;
    }
    return null;
  }

  static List<CustomerVisits> _rank(List<Json> rows, Period period) {
    final unique = {for (final row in rows) row['id'] as String: row};
    final groups = <String, List<Json>>{};
    for (final order in reportOrders(unique.values.toList(), period)) {
      groups.putIfAbsent(customerIdentity(order), () => []).add(order);
    }
    final result =
        groups.entries.map((group) {
          group.value.sort((a, b) {
            final byDate = DateTime.parse(
              b['created_at'] as String,
            ).compareTo(DateTime.parse(a['created_at'] as String));
            return byDate != 0 ? byDate : '${a['id']}'.compareTo('${b['id']}');
          });
          return CustomerVisits(group.key, group.value);
        }).toList();
    result.sort((a, b) {
      final byVisits = b.visits.compareTo(a.visits);
      if (byVisits != 0) return byVisits;
      final byLatest = b.lastVisit.compareTo(a.lastVisit);
      return byLatest != 0 ? byLatest : a.identity.compareTo(b.identity);
    });
    return result;
  }
}

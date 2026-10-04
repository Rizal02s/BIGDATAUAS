import 'domain.dart';

int orderPaid(Json order) => ((order['payments'] as List?) ?? [])
    .where((p) => p['voided_at'] == null)
    .fold<int>(0, (sum, p) => sum + money(p['amount']));

int orderRemaining(Json order) =>
    (money(order['total']) - orderPaid(order)).clamp(0, money(order['total']));

String periodLabel(Period period) {
  const months = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];
  final first = jakarta(period.start);
  final last = jakarta(period.end.subtract(const Duration(seconds: 1)));
  if (first.year == last.year && first.month != last.month) {
    return '${first.year}';
  }
  final month = '${months[first.month - 1]} ${first.year}';
  return first.day == last.day ? '${first.day} $month' : month;
}

List<Json> reportOrders(List<Json> orders, Period period) =>
    orders
        .where(
          (o) =>
              o['deleted_at'] == null &&
              period.contains(DateTime.parse(o['created_at'] as String)),
        )
        .toList()
      ..sort((a, b) {
        final byDate = (a['created_at'] as String).compareTo(
          b['created_at'] as String,
        );
        return byDate != 0 ? byDate : '${a['id']}'.compareTo('${b['id']}');
      });

/// Only customer-facing fields can enter a receipt, for every account role.
class CustomerReceipt {
  final String customer, phone, number;
  final DateTime createdAt;
  final List<ReceiptLine> lines;
  final List<String> methods;
  final int discount, total, paid, remaining;
  CustomerReceipt.fromOrder(Json order)
    : customer = order['customer_name'] as String,
      phone = order['phone'] as String? ?? '',
      number = '${order['number']}',
      createdAt = DateTime.parse(order['created_at'] as String),
      lines =
          (order['items'] as List)
              .map(
                (item) => ReceiptLine(
                  item['name'] as String,
                  money(item['quantity']),
                  money(item['price']),
                ),
              )
              .toList(),
      methods =
          ((order['payments'] as List?) ?? [])
              .where((p) => p['voided_at'] == null)
              .map((p) => p['method'] as String? ?? 'Pembayaran')
              .toSet()
              .toList(),
      discount = money(order['discount']),
      total = money(order['total']),
      paid = orderPaid(order),
      remaining = orderRemaining(order);
}

class ReceiptLine {
  final String service;
  final int quantity, price;
  const ReceiptLine(this.service, this.quantity, this.price);
}

class WorkEntry {
  final Json order, item;
  const WorkEntry(this.order, this.item);
  int get quantity => money(item['quantity']);
  int get wage => money(item['labor_fee']) * quantity;
  String get status => item['status'] as String? ?? 'Masuk';
}

class WorkerReport {
  final List<WorkEntry> entries;
  WorkerReport(List<Json> orders, String workerId)
    : entries = [
        for (final order in orders)
          for (final item in (order['items'] as List))
            if (item['worker_id'] == workerId)
              WorkEntry(order, Json.from(item as Map)),
      ];
  int get total => entries.fold(0, (sum, e) => sum + e.wage);
  int get quantity => entries.fold(0, (sum, e) => sum + e.quantity);
  int get orderCount => entries.map((e) => e.order['id']).toSet().length;
  int get completed => entries
      .where((e) => ['Selesai', 'Diambil'].contains(e.status))
      .fold(0, (sum, e) => sum + e.quantity);
}

class OrderReport {
  final List<Json> orders;
  final bool includeWages;
  OrderReport(this.orders, {required this.includeWages});
  int get revenue => orders.fold(0, (sum, o) => sum + money(o['total']));
  int get discount => orders.fold(0, (sum, o) => sum + money(o['discount']));
  int get paid => orders.fold(0, (sum, o) => sum + orderPaid(o));
  int get remaining => orders.fold(0, (sum, o) => sum + orderRemaining(o));
  int get unpaidCount => orders.where((o) => orderRemaining(o) > 0).length;
  int get quantity => orders.fold(
    0,
    (sum, o) =>
        sum +
        (o['items'] as List).fold<int>(0, (n, i) => n + money(i['quantity'])),
  );
  int get labor =>
      includeWages
          ? orders.fold(0, (sum, o) => sum + money(o['labor_total']))
          : 0;
  // Customer identity is not stored as a separate entity. Phone takes priority;
  // otherwise matching names are treated as the same customer in this report.
  int get unpaidCustomers =>
      orders
          .where((o) => orderRemaining(o) > 0)
          .map((o) {
            final phone = (o['phone'] as String? ?? '').replaceAll(
              RegExp(r'\D'),
              '',
            );
            final normalized =
                phone.startsWith('0') ? '62${phone.substring(1)}' : phone;
            return normalized.isEmpty
                ? (o['customer_name'] as String).trim().toLowerCase()
                : normalized;
          })
          .toSet()
          .length;
}

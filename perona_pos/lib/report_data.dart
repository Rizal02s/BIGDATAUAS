import 'domain.dart';

int orderPaid(Json order) => ((order['payments'] as List?) ?? [])
    .where((p) => p['voided_at'] == null)
    .fold<int>(0, (sum, p) => sum + money(p['amount']));

int orderRemaining(Json order) =>
    (money(order['total']) - orderPaid(order)).clamp(0, money(order['total']));

enum PaymentCategory {
  unpaid('Customer belum lunas', null),
  qris('Bayar QRIS', 'QRIS'),
  cash('Bayar tunai', 'Tunai');

  final String label;
  final String? method;
  const PaymentCategory(this.label, this.method);
}

int orderPaidByMethod(Json order, String method) =>
    ((order['payments'] as List?) ?? [])
        .where((p) => p['voided_at'] == null && p['method'] == method)
        .fold<int>(0, (sum, p) => sum + money(p['amount']));

String customerKey(Json order) {
  final phone = (order['phone'] as String? ?? '').replaceAll(RegExp(r'\D'), '');
  if (phone.isEmpty) {
    return (order['customer_name'] as String).trim().toLowerCase();
  }
  return phone.startsWith('0') ? '62${phone.substring(1)}' : phone;
}

class PaymentOverview {
  final List<Json> orders;
  PaymentOverview(List<Json> rows, Period period)
    : orders = reportOrders(rows, period);

  List<Json> ordersFor(PaymentCategory category) =>
      orders
          .where(
            (order) =>
                category.method == null
                    ? orderRemaining(order) > 0
                    : orderPaidByMethod(order, category.method!) > 0,
          )
          .toList();

  int amountFor(PaymentCategory category) => ordersFor(category).fold(
    0,
    (sum, order) =>
        sum +
        (category.method == null
            ? orderRemaining(order)
            : orderPaidByMethod(order, category.method!)),
  );

  int customerCountFor(PaymentCategory category) =>
      ordersFor(category).map(customerKey).toSet().length;
}

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
  WorkerReport(List<Json> orders, String? workerId)
    : entries = [
        for (final order in orders)
          for (final item in (order['items'] as List))
            if (workerId == null || item['worker_id'] == workerId)
              WorkEntry(order, Json.from(item as Map)),
      ];
  int get total => entries.fold(0, (sum, e) => sum + e.wage);
  int get quantity => entries.fold(0, (sum, e) => sum + e.quantity);
  int get orderCount => entries.map((e) => e.order['id']).toSet().length;
  int get completed => entries
      .where((e) => ['Selesai', 'Diambil'].contains(e.status))
      .fold(0, (sum, e) => sum + e.quantity);

  List<WorkNote> get notes {
    final byOrder = <String, WorkNote>{};
    for (final entry in entries) {
      byOrder
          .putIfAbsent(
            entry.order['id'] as String,
            () => WorkNote(entry.order, []),
          )
          .entries
          .add(entry);
    }
    return byOrder.values.toList();
  }
}

class WorkNote {
  final Json order;
  final List<WorkEntry> entries;
  WorkNote(this.order, this.entries);
  int get wage => entries.fold(0, (sum, entry) => sum + entry.wage);
  String get services => entries
      .map((entry) => '${entry.item['name']} × ${entry.quantity}')
      .join('\n');
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
          .map(customerKey)
          .toSet()
          .length;
}

import 'domain.dart';
import 'report_data.dart';

List<Json> orderWorkItems(Json order, String? workerId) =>
    ((order['items'] as List?) ?? [])
        .map((item) => Json.from(item as Map))
        .where((item) => workerId == null || item['worker_id'] == workerId)
        .toList();

String orderWorkStatus(Json order, {String? workerId}) {
  final statuses =
      orderWorkItems(
        order,
        workerId,
      ).map((item) => item['status'] as String? ?? 'Masuk').toSet();
  if (statuses.isEmpty) return 'Belum ada layanan';
  if (statuses.length == 1) return statuses.single;
  return statuses.every((status) => ['Selesai', 'Diambil'].contains(status))
      ? 'Selesai'
      : 'Dikerjakan';
}

String orderPaymentStatus(Json order) {
  final paid = orderPaid(order);
  return paid >= money(order['total'])
      ? 'Lunas'
      : paid > 0
      ? 'DP'
      : 'Belum bayar';
}

enum WorkFilter {
  all('Semua status'),
  newOrder('Masuk'),
  inProgress('Dikerjakan'),
  ready('Selesai'),
  pickedUp('Diambil'),
  notPickedUp('Belum diambil');

  final String label;
  const WorkFilter(this.label);
}

enum PaymentFilter {
  all('Semua pembayaran'),
  outstanding('Belum lunas'),
  unpaid('Belum bayar'),
  deposit('DP'),
  paid('Lunas');

  final String label;
  const PaymentFilter(this.label);
}

String _phoneDigits(String input) {
  var digits = input.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('00')) digits = digits.substring(2);
  if (digits.startsWith('0')) return '62${digits.substring(1)}';
  if (digits.startsWith('8')) return '62$digits';
  return digits;
}

class OrderFilter {
  final String query;
  final WorkFilter work;
  final PaymentFilter payment;
  const OrderFilter({
    this.query = '',
    this.work = WorkFilter.all,
    this.payment = PaymentFilter.all,
  });
  bool get active =>
      query.trim().isNotEmpty ||
      work != WorkFilter.all ||
      payment != PaymentFilter.all;

  OrderFilter copyWith({
    String? query,
    WorkFilter? work,
    PaymentFilter? payment,
  }) => OrderFilter(
    query: query ?? this.query,
    work: work ?? this.work,
    payment: payment ?? this.payment,
  );

  bool matches(Json order, {String? workerId}) {
    final items = orderWorkItems(order, workerId);
    if (workerId != null && items.isEmpty) return false;
    final workStatus = orderWorkStatus(order, workerId: workerId);
    final workMatches = switch (work) {
      WorkFilter.all => true,
      WorkFilter.newOrder => workStatus == 'Masuk',
      WorkFilter.inProgress => workStatus == 'Dikerjakan',
      WorkFilter.ready => workStatus == 'Selesai',
      WorkFilter.pickedUp => workStatus == 'Diambil',
      WorkFilter.notPickedUp => items.any(
        (item) => item['status'] != 'Diambil',
      ),
    };
    if (!workMatches) return false;
    final paymentStatus = orderPaymentStatus(order);
    final paymentMatches = switch (payment) {
      PaymentFilter.all => true,
      PaymentFilter.outstanding => paymentStatus != 'Lunas',
      PaymentFilter.unpaid => paymentStatus == 'Belum bayar',
      PaymentFilter.deposit => paymentStatus == 'DP',
      PaymentFilter.paid => paymentStatus == 'Lunas',
    };
    if (!paymentMatches) return false;
    final term = query.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (term.isEmpty) return true;
    final name = (order['customer_name'] as String? ?? '')
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
    if (name.contains(term)) return true;
    final numberTerm = RegExp(
      r'^(?:nota\s*#?\s*|#\s*)?(\d+)$',
    ).firstMatch(term)?.group(1);
    if (numberTerm != null) {
      final number = int.tryParse(numberTerm)?.toString() ?? numberTerm;
      if ('${order['number']}'.contains(number)) return true;
    }
    if (!RegExp(r'^[+\d\s().-]+$').hasMatch(term)) return false;
    final digits = _phoneDigits(term);
    return digits.isNotEmpty &&
        _phoneDigits(order['phone'] as String? ?? '').contains(digits);
  }

  List<Json> apply(List<Json> rows, Period period, {String? workerId}) =>
      reportOrders(
          rows,
          period,
        ).where((order) => matches(order, workerId: workerId)).toList()
        ..sort((a, b) {
          final byDate = DateTime.parse(
            b['created_at'] as String,
          ).compareTo(DateTime.parse(a['created_at'] as String));
          return byDate != 0 ? byDate : '${a['id']}'.compareTo('${b['id']}');
        });
}

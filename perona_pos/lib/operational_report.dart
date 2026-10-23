import 'domain.dart';

class OperationalReport {
  final int count,
      gross,
      revenue,
      discount,
      pending,
      ready,
      pickedUp,
      overdue,
      dueToday;
  final int outstandingPeriod,
      outstandingAll,
      received,
      cash,
      qris,
      transfer,
      receiptCount;
  final List<Json> payments;
  OperationalReport.fromJson(Json data)
    : count = money(data['count']),
      gross = money(data['gross']),
      revenue = money(data['revenue']),
      discount = money(data['discount']),
      pending = money(data['pending']),
      ready = money(data['ready']),
      pickedUp = money(data['picked_up']),
      overdue = money(data['overdue']),
      dueToday = money(data['due_today']),
      outstandingPeriod = money(data['outstanding_period']),
      outstandingAll = money(data['outstanding_all']),
      received = money(data['received']),
      cash = money(data['cash']),
      qris = money(data['qris']),
      transfer = money(data['transfer']),
      receiptCount = money(data['receipt_count']),
      payments =
          ((data['payments'] as List?) ?? [])
              .map((row) => Json.from(row as Map))
              .toList();
}

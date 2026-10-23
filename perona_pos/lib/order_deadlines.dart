import 'domain.dart';
import 'order_filters.dart';

enum DeadlineFilter {
  all('Semua'),
  overdue('Terlambat'),
  today('Hari ini'),
  upcoming('Mendatang'),
  unscheduled('Tanpa estimasi');

  final String label;
  const DeadlineFilter(this.label);
}

DateTime? orderDueDate(Json order) =>
    DateTime.tryParse(order['due_date'] as String? ?? '');

bool orderNeedsWork(Json order, {String? workerId}) =>
    order['deleted_at'] == null &&
    orderWorkItems(
      order,
      workerId,
    ).any((item) => !['Selesai', 'Diambil'].contains(item['status']));

DeadlineFilter orderDeadline(Json order, {DateTime? now}) {
  final due = orderDueDate(order);
  if (due == null) return DeadlineFilter.unscheduled;
  final wib = jakarta(now ?? DateTime.now());
  final today = DateTime.utc(wib.year, wib.month, wib.day);
  final date = DateTime.utc(due.year, due.month, due.day);
  if (date.isBefore(today)) return DeadlineFilter.overdue;
  if (date == today) return DeadlineFilter.today;
  return DeadlineFilter.upcoming;
}

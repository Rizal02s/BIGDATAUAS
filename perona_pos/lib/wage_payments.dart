import 'domain.dart';

class WageLedger {
  final String workerId, workerName, fingerprint;
  final int earned, paid, remaining, excess;
  final List<Json> notes, history;
  WageLedger.fromJson(Json row)
    : workerId = row['worker_id'] as String,
      workerName = row['worker_name'] as String,
      fingerprint = row['fingerprint'] as String,
      earned = money(row['earned']),
      paid = money(row['paid']),
      remaining = money(row['remaining']),
      excess = money(row['excess']),
      notes =
          ((row['notes'] as List?) ?? [])
              .map((n) => Json.from(n as Map))
              .toList(),
      history =
          ((row['history'] as List?) ?? [])
              .map((n) => Json.from(n as Map))
              .toList();
}

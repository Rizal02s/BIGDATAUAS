import 'domain.dart';

String attendanceDate(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

class AttendanceEntry {
  final Json data;
  AttendanceEntry(Json value) : data = Json.unmodifiable(value);
  String get id => data['id'] as String;
  String get employeeId => data['employee_id'] as String;
  String get name => data['employee_name'] as String? ?? 'Pegawai';
  String get status => data['status'] as String;
  DateTime get date => DateTime.parse(data['business_date'] as String);
  DateTime? get checkIn => DateTime.tryParse(data['check_in'] as String? ?? '');
  DateTime? get checkOut =>
      DateTime.tryParse(data['check_out'] as String? ?? '');
  String get notes => data['notes'] as String? ?? '';
  String get reason => data['correction_reason'] as String? ?? '';
  int get version => money(data['version']);
  bool get isOpen => status == 'Hadir' && checkOut == null;
}

class AttendanceToday {
  final DateTime serverTime, date;
  final AttendanceEntry? today, open;
  AttendanceToday.fromJson(Json value)
    : serverTime = DateTime.parse(value['server_time'] as String),
      date = DateTime.parse(value['date'] as String),
      today =
          value['today'] == null
              ? null
              : AttendanceEntry(Json.from(value['today'] as Map)),
      open =
          value['open'] == null
              ? null
              : AttendanceEntry(Json.from(value['open'] as Map));
}

class AttendanceReport {
  final int count, present, permission, sick, open, minutes;
  final bool hasMore;
  final List<AttendanceEntry> rows;
  final List<Json> employees;
  AttendanceReport.fromJson(Json value)
    : count = money(value['count']),
      present = money(value['present']),
      permission = money(value['permission']),
      sick = money(value['sick']),
      open = money(value['open']),
      minutes = money(value['minutes']),
      hasMore = value['has_more'] == true,
      rows =
          ((value['rows'] as List?) ?? [])
              .map((r) => AttendanceEntry(Json.from(r as Map)))
              .toList(),
      employees =
          ((value['employees'] as List?) ?? [])
              .map((r) => Json.from(r as Map))
              .toList();
}

String attendanceDuration(int minutes) =>
    '${minutes ~/ 60} jam ${minutes % 60} menit';

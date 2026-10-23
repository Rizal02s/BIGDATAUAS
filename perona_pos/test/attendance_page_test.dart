import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perona_pos/app_theme.dart';
import 'package:perona_pos/attendance_data.dart';
import 'package:perona_pos/domain.dart';
import 'package:perona_pos/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_page_test.dart'
    show DemoRepository, capture, loadPreviewFonts, previewKey, pumpHome;

class AttendanceRepository extends DemoRepository {
  final entries = <Json>[];
  final requests = <(String, String, String)>[];
  final corrections = <Json>[];
  final periods = <Period>[];
  final pages = <int>[];
  final employees = <String?>[];
  bool missing = false, lostResponse = false;
  Completer<void>? pending;
  String get date => attendanceDate(jakarta(DateTime.now()));
  Json entry({String id = 'a', String status = 'Hadir', bool open = false}) => {
    'id': id,
    'employee_id': 'staff-a',
    'employee_name': 'Dina',
    'business_date': date,
    'status': status,
    'check_in': status == 'Hadir' ? '${date}T01:00:00Z' : null,
    'check_out': status == 'Hadir' && !open ? '${date}T09:00:00Z' : null,
    'notes': status == 'Hadir' ? '' : 'Keperluan keluarga',
    'version': 1,
  };
  @override
  Future<AttendanceToday> attendanceToday() async {
    if (missing) {
      throw const PostgrestException(
        code: 'PGRST202',
        message: 'missing attendance_today',
      );
    }
    final own = entries.where((r) => r['employee_id'] == 'staff-a').toList();
    return AttendanceToday.fromJson({
      'server_time': '${date}T01:00:00Z',
      'date': date,
      'today': own.where((r) => r['business_date'] == date).firstOrNull,
      'open':
          own
              .where((r) => r['status'] == 'Hadir' && r['check_out'] == null)
              .firstOrNull,
    });
  }

  @override
  Future<AttendanceReport> attendanceReport(
    Period period, {
    String? employee,
    int page = 0,
  }) async {
    periods.add(period);
    pages.add(page);
    employees.add(employee);
    if (missing) {
      throw const PostgrestException(
        code: 'PGRST202',
        message: 'missing attendance_report',
      );
    }
    final all =
        entries
            .where(
              (r) =>
                  period.contains(
                    jakartaToUtc(DateTime.parse(r['business_date'] as String)),
                  ) &&
                  (employee == null || r['employee_id'] == employee),
            )
            .toList();
    return AttendanceReport.fromJson({
      'count': all.length,
      'present': all.where((r) => r['status'] == 'Hadir').length,
      'permission': all.where((r) => r['status'] == 'Izin').length,
      'sick': 0,
      'minutes': 480,
      'open':
          all
              .where((r) => r['status'] == 'Hadir' && r['check_out'] == null)
              .length,
      'rows': all.skip(page * 30).take(30).toList(),
      'has_more': all.length > (page + 1) * 30,
      'employees':
          all.isEmpty
              ? []
              : [
                {
                  'employee_id': 'staff-a',
                  'name': 'Dina',
                  'present': 1,
                  'permission': 0,
                  'sick': 0,
                  'open': 0,
                  'minutes': 480,
                },
              ],
    });
  }

  @override
  Future<AttendanceEntry> recordAttendance(
    String requestId,
    String action,
    String notes,
  ) async {
    requests.add((requestId, action, notes));
    if (pending != null) await pending!.future;
    if (action == 'out') {
      entries[0] = {...entries[0], 'check_out': '${date}T09:00:00Z'};
    } else if (entries.isEmpty) {
      entries.add({
        ...entry(status: action == 'in' ? 'Hadir' : action, open: true),
        'notes': notes,
      });
    }
    if (lostResponse) {
      lostResponse = false;
      throw const AuthException('Respons terputus, coba lagi');
    }
    return AttendanceEntry(entries.first);
  }

  @override
  Future<void> correctAttendance(Json values) async {
    corrections.add(Json.from(values));
  }

  @override
  Future<List<Json>> attendanceHistory(String id) async => [
    {
      'at': '${date}T09:00:00Z',
      'actor_name': 'Rizal',
      'action': 'attendance.correct',
      'before': entry(),
      'after': {
        ...entry(status: 'Izin'),
        'correction_reason': 'Salah pencatatan',
      },
    },
  ];
}

Future<void> open(
  WidgetTester tester,
  AttendanceRepository repo, {
  String role = 'technician',
  bool narrow = false,
}) async {
  tester.view.physicalSize = Size(narrow ? 320 : 412, 892);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  repo.accessRole = role;
  await tester.pumpWidget(
    RepaintBoundary(
      key: previewKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: peronaTheme(),
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(narrow ? 1.5 : 1)),
              child: child!,
            ),
        home: AttendancePage(repo: repo, staff: await repo.staff()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> press(
  WidgetTester tester,
  Finder target, {
  double delta = 300,
}) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      delta,
      maxScrolls: 100,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(target);
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.35);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadPreviewFonts);
  testWidgets('Self punches in/out with confirmation, no owner corrections', (
    tester,
  ) async {
    final repo = AttendanceRepository();
    await open(tester, repo);
    expect(
      find.byKey(const ValueKey('add-attendance-correction')),
      findsNothing,
    );
    await press(tester, find.byKey(const ValueKey('attendance-in')));
    expect(repo.requests, isEmpty);
    await press(tester, find.byKey(const ValueKey('confirm-attendance')));
    expect(repo.requests.single.$2, 'in');
    expect(find.byKey(const ValueKey('attendance-out')), findsOneWidget);
    await press(tester, find.byKey(const ValueKey('attendance-out')));
    await press(tester, find.byKey(const ValueKey('confirm-attendance')));
    expect(repo.requests.last.$2, 'out');
    expect(find.byKey(const ValueKey('attendance-in')), findsNothing);
    expect(find.textContaining('Pulang:'), findsWidgets);
  });
  testWidgets(
    'Permission needs note; lost response retries same ID and payload',
    (tester) async {
      final repo = AttendanceRepository()..lostResponse = true;
      await open(tester, repo);
      await press(tester, find.byKey(const ValueKey('attendance-Izin')));
      await press(tester, find.byKey(const ValueKey('confirm-attendance')));
      expect(repo.requests, isEmpty);
      await tester.enterText(
        find.byKey(const ValueKey('attendance-note')),
        'Keperluan keluarga',
      );
      await press(tester, find.byKey(const ValueKey('confirm-attendance')));
      expect(find.textContaining('Respons terputus'), findsOneWidget);
      await press(tester, find.byKey(const ValueKey('confirm-attendance')));
      expect(repo.requests[0], repo.requests[1]);
      expect(repo.entries.length, 1);
      expect(find.byKey(const ValueKey('attendance-in')), findsNothing);
    },
  );
  testWidgets('Double tap cannot issue multiple requests while waiting', (
    tester,
  ) async {
    final wait = Completer<void>();
    final repo = AttendanceRepository()..pending = wait;
    await open(tester, repo);
    await press(tester, find.byKey(const ValueKey('attendance-in')));
    final button = find.byKey(const ValueKey('confirm-attendance'));
    await tester.tap(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pump();
    expect(repo.requests.length, 1);
    wait.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('attendance-out')), findsOneWidget);
  });
  testWidgets(
    'Owner sees report, correction validation and version, history, small screen',
    (tester) async {
      final repo = AttendanceRepository();
      repo.entries.add(repo.entry());
      await open(tester, repo, role: 'owner', narrow: true);
      await capture(tester, 'attendance-owner-small');
      await press(tester, find.byKey(const ValueKey('correct-attendance-a')));
      await press(
        tester,
        find.byKey(const ValueKey('save-attendance-correction')),
      );
      expect(repo.corrections, isEmpty);
      await tester.enterText(
        find.byKey(const ValueKey('correction-reason')),
        'Pegawai lupa absen',
      );
      await capture(tester, 'attendance-correction');
      await press(
        tester,
        find.byKey(const ValueKey('save-attendance-correction')),
      );
      expect(repo.corrections.single['p_version'], 1);
      expect(repo.corrections.single['p_employee'], 'staff-a');
      expect(repo.corrections.single['p_in'], '${repo.date}T01:00:00.000Z');
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      await press(tester, find.byKey(const ValueKey('history-attendance-a')));
      expect(find.textContaining('Sebelum: Hadir'), findsOneWidget);
      expect(find.textContaining('Sesudah: Izin'), findsOneWidget);
      expect(find.text('Alasan: Salah pencatatan'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Missing migration stays local to attendance; retry loads it', (
    tester,
  ) async {
    final repo = AttendanceRepository()..missing = true;
    await open(tester, repo);
    expect(find.textContaining('014_daily_attendance.sql'), findsWidgets);
    expect(find.byKey(const ValueKey('attendance-in')), findsNothing);
    repo.missing = false;
    await press(tester, find.text('Muat ulang absensi saya'));
    expect(find.byKey(const ValueKey('attendance-in')), findsOneWidget);
  });
  testWidgets(
    'Report pagination appends; owner filter and calendar are available',
    (tester) async {
      final repo = AttendanceRepository();
      for (var i = 0; i < 31; i++) {
        repo.entries.add(repo.entry(id: 'a-$i'));
      }
      await open(tester, repo, role: 'owner');
      await press(tester, find.byKey(const ValueKey('attendance-next')));
      expect(repo.pages, [0, 1]);
      expect(
        find.byKey(const ValueKey('correct-attendance-a-30')),
        findsOneWidget,
      );
      await press(
        tester,
        find.byKey(const ValueKey('attendance-employee')),
        delta: -400,
      );
      await tester.tap(find.text('Dina').last);
      await tester.pumpAndSettle();
      expect(repo.employees.last, 'staff-a');
      await press(tester, find.byKey(const ValueKey('attendance-period')));
      expect(find.byType(DateRangePickerDialog), findsOneWidget);
    },
  );
  testWidgets(
    'Previous day open attendance shows checkout before a new checkin',
    (tester) async {
      final repo = AttendanceRepository();
      final yesterday = jakarta(
        DateTime.now(),
      ).subtract(const Duration(days: 1));
      repo.entries.add({
        ...repo.entry(open: true),
        'business_date': attendanceDate(yesterday),
        'check_in':
            jakartaToUtc(
              DateTime(yesterday.year, yesterday.month, yesterday.day, 20),
            ).toIso8601String(),
      });
      await open(tester, repo, narrow: true);
      expect(find.textContaining('Absen sebelumnya'), findsOneWidget);
      expect(find.byKey(const ValueKey('attendance-in')), findsNothing);
      await capture(tester, 'attendance-self');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Calendar changes inclusive report period and resets paging', (
    tester,
  ) async {
    final repo = AttendanceRepository();
    await open(tester, repo, role: 'owner');
    await press(tester, find.byKey(const ValueKey('attendance-period')));
    await tester.tap(find.byTooltip('Switch to input'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '01/10/2021');
    await tester.enterText(fields.at(1), '01/12/2021');
    await tester.tap(find.text('Pilih').last);
    await tester.pumpAndSettle();
    expect(repo.periods.last.start, DateTime.utc(2021, 1, 9, 17));
    expect(repo.periods.last.end, DateTime.utc(2021, 1, 12, 17));
    expect(repo.pages.last, 0);
    expect(
      find.text('Belum ada catatan absensi pada periode ini.'),
      findsOneWidget,
    );
  });
  testWidgets(
    'Owner switches presence to permission with required note and reason, removing times',
    (tester) async {
      final repo = AttendanceRepository();
      repo.entries.add(repo.entry());
      await open(tester, repo, role: 'owner');
      await press(tester, find.byKey(const ValueKey('correct-attendance-a')));
      await press(tester, find.byKey(const ValueKey('correction-status')));
      await tester.tap(find.text('Izin').last);
      await tester.pumpAndSettle();
      await press(
        tester,
        find.byKey(const ValueKey('save-attendance-correction')),
      );
      expect(repo.corrections, isEmpty);
      await tester.enterText(
        find.byKey(const ValueKey('correction-note')),
        'Keperluan keluarga',
      );
      await tester.enterText(
        find.byKey(const ValueKey('correction-reason')),
        'Koreksi catatan pegawai',
      );
      await press(
        tester,
        find.byKey(const ValueKey('save-attendance-correction')),
      );
      expect(repo.corrections.single['p_status'], 'Izin');
      expect(repo.corrections.single['p_in'], isNull);
      expect(repo.corrections.single['p_out'], isNull);
    },
  );
  testWidgets(
    'Owner opens attendance from Internal; admin and technicians have own shortcut',
    (tester) async {
      final repo = AttendanceRepository();
      await pumpHome(tester, repo, 'owner');
      await tester.tap(find.text('Internal'));
      await tester.pumpAndSettle();
      await press(tester, find.byKey(const ValueKey('open-attendance')));
      expect(find.byType(AttendancePage), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await pumpHome(tester, AttendanceRepository(), 'admin');
      expect(find.text('Internal'), findsNothing);
      await press(tester, find.byKey(const ValueKey('open-my-attendance')));
      expect(
        find.byKey(const ValueKey('add-attendance-correction')),
        findsNothing,
      );
    },
  );
}

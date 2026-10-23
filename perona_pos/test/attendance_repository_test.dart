import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:perona_pos/attendance_data.dart';
import 'package:perona_pos/domain.dart';
import 'package:perona_pos/main.dart' show errorText;
import 'package:perona_pos/repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'Absensi uses RPC server times and inclusive WIB dates, no employee supplied for punches',
    () async {
      final calls = <http.Request>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((r) async {
          calls.add(r);
          final result =
              r.url.path.endsWith('attendance_today')
                  ? {
                    'server_time': '2026-10-23T01:00:00Z',
                    'date': '2026-10-23',
                    'today': null,
                    'open': null,
                  }
                  : r.url.path.endsWith('attendance_report')
                  ? {
                    'present': 1001,
                    'count': 1001,
                    'minutes': 125,
                    'has_more': true,
                    'rows': [],
                  }
                  : {
                    'id': 'a',
                    'employee_id': 'staff',
                    'business_date': '2026-10-23',
                    'status': 'Hadir',
                    'check_in': '2026-10-23T01:00:00Z',
                    'version': 1,
                  };
          return http.Response(
            jsonEncode(result),
            200,
            headers: {'content-type': 'application/json'},
            request: r,
          );
        }),
      );
      addTearDown(client.dispose);
      final repo = Repository(client)..accessRole = 'technician';
      expect((await repo.attendanceToday()).date, DateTime(2026, 10, 23));
      final entry = await repo.recordAttendance(
        'request-1',
        'in',
        '  Catatan  ',
      );
      expect(entry.isOpen, true);
      expect(jsonDecode(calls.last.body), {
        'p_request_id': 'request-1',
        'p_action': 'in',
        'p_notes': 'Catatan',
      });
      final report = await repo.attendanceReport(
        Period.betweenDates(DateTime(2026, 10, 1), DateTime(2026, 10, 23)),
        employee: 'staff',
        page: 2,
      );
      expect(jsonDecode(calls.last.body), {
        'p_start': '2026-10-01',
        'p_end': '2026-10-23',
        'p_employee': 'staff',
        'p_page': 2,
      });
      expect(
        [report.present, report.hasMore, attendanceDuration(report.minutes)],
        [1001, true, '2 jam 5 menit'],
      );
    },
  );
  test(
    'Only owner can invoke correction/history and missing migration explains activation',
    () async {
      var calls = 0;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((r) async {
          calls++;
          return http.Response(
            '[]',
            200,
            request: r,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final repo = Repository(client)..accessRole = 'admin';
      await expectLater(repo.correctAttendance({}), throwsStateError);
      await expectLater(repo.attendanceHistory('a'), throwsStateError);
      expect(calls, 0);
      repo.accessRole = 'owner';
      await repo.correctAttendance({'p_reason': 'Koreksi pencatatan'});
      expect(await repo.attendanceHistory('a'), isEmpty);
      expect(calls, 2);
      expect(
        errorText(
          const PostgrestException(
            code: 'PGRST202',
            message: 'missing record_attendance',
          ),
        ),
        contains('014_daily_attendance.sql'),
      );
    },
  );
}

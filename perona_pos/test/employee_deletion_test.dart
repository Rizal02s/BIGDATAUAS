import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perona_pos/domain.dart';
import 'package:perona_pos/employee_accounts.dart';
import 'home_page_test.dart'
    show DemoRepository, pumpHome, capture, loadPreviewFonts;

class PeopleRepository extends DemoRepository {
  final people = <Json>[
    {'id': 'owner-a', 'name': 'Rizal', 'role': 'owner'},
    {'id': 'owner-b', 'name': 'Owner Kedua', 'role': 'owner'},
    {'id': 'staff-a', 'name': 'Dina', 'role': 'technician'},
    {'id': 'pending-a', 'name': 'Akun Baru', 'role': 'pending'},
  ];
  final deletions = <(String, String)>[];
  bool failDeletion = false, pending = false;
  Completer<void>? waiting;
  @override
  String get userId => 'owner-a';
  @override
  Future<List<Json>> staff() async => people.map(Json.from).toList();
  @override
  Future<void> deleteEmployee(Json person, String reason) async {
    deletions.add((person['id'] as String, reason));
    if (waiting != null) await waiting!.future;
    final index = people.indexWhere((p) => p['id'] == person['id']);
    if (failDeletion) {
      throw const EmployeeDeletionFailure(
        'Deploy fungsi delete-employee-account terlebih dahulu.',
      );
    }
    people[index] = {
      ...people[index],
      'role': 'disabled',
      'deleted_at': '2026-10-23T00:00:00Z',
      'delete_reason': reason,
      'auth_deleted_at': pending ? null : '2026-10-23T00:01:00Z',
    };
    if (pending) {
      throw const EmployeeDeletionFailure(
        'Akses aplikasi dicabut. Penghapusan login belum selesai.',
        pending: true,
      );
    }
  }
}

Future<void> openPeople(
  WidgetTester tester,
  PeopleRepository repo, {
  bool narrow = false,
}) async {
  await pumpHome(
    tester,
    repo,
    'owner',
    size: Size(narrow ? 320 : 412, 892),
    textScale: narrow ? 1.5 : 1,
  );
  await tester.tap(find.text('Internal'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(
    find.byKey(const ValueKey('open-internal-people')),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('open-internal-people')));
  await tester.pumpAndSettle();
}

Future<void> showDelete(WidgetTester tester, String id) async {
  final menu = find.byKey(ValueKey('employee-actions-$id'));
  await tester.scrollUntilVisible(
    menu,
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await Scrollable.ensureVisible(tester.element(menu), alignment: 0.35);
  await tester.pumpAndSettle();
  await tester.tap(menu);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Hapus akun pegawai'));
  await tester.pumpAndSettle();
}

Future<void> confirm(WidgetTester tester) async {
  await tester.ensureVisible(
    find.byKey(const ValueKey('confirm-delete-employee')),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('confirm-delete-employee')));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadPreviewFonts);
  testWidgets(
    'Owner confirms a named employee and reason; deleted account disappears from management',
    (tester) async {
      final repo = PeopleRepository();
      await openPeople(tester, repo);
      await showDelete(tester, 'staff-a');
      expect(find.text('Hapus akun pegawai?'), findsOneWidget);
      expect(find.textContaining('Order, foto, pembayaran'), findsOneWidget);
      await confirm(tester);
      expect(repo.deletions, isEmpty);
      await tester.enterText(
        find.byKey(const ValueKey('employee-delete-reason')),
        'Pegawai telah keluar',
      );
      await capture(tester, 'employee-delete-confirmation');
      await confirm(tester);
      expect(repo.deletions, [('staff-a', 'Pegawai telah keluar')]);
      expect(
        find.byKey(const ValueKey('employee-actions-staff-a')),
        findsNothing,
      );
      expect(
        repo.people.firstWhere((p) => p['id'] == 'staff-a')['name'],
        'Dina',
      );
    },
  );
  testWidgets(
    'Cancel does not delete; own account and other owners have no delete action',
    (tester) async {
      final repo = PeopleRepository();
      await openPeople(tester, repo);
      expect(
        find.byKey(const ValueKey('employee-actions-owner-a')),
        findsNothing,
      );
      final other = find.byKey(const ValueKey('employee-actions-owner-b'));
      await tester.scrollUntilVisible(
        other,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(other);
      await tester.pumpAndSettle();
      await tester.tap(other);
      await tester.pumpAndSettle();
      expect(find.text('Hapus akun pegawai'), findsNothing);
      await tester.tapAt(const Offset(8, 80));
      await tester.pumpAndSettle();
      await showDelete(tester, 'pending-a');
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(repo.deletions, isEmpty);
    },
  );
  testWidgets(
    'Missing deployment shows error without claiming success and retry retains reason',
    (tester) async {
      final repo = PeopleRepository()..failDeletion = true;
      await openPeople(tester, repo);
      await showDelete(tester, 'staff-a');
      await tester.enterText(
        find.byKey(const ValueKey('employee-delete-reason')),
        'Pegawai keluar',
      );
      await confirm(tester);
      expect(find.textContaining('Deploy fungsi'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('employee-delete-reason')),
            )
            .enabled,
        false,
      );
      repo.failDeletion = false;
      await confirm(tester);
      expect(repo.deletions.length, 2);
      expect(repo.deletions[0], repo.deletions[1]);
    },
  );
  testWidgets(
    'Partial deletion remains in list with finish action and completes safely on retry',
    (tester) async {
      final repo = PeopleRepository()..pending = true;
      await openPeople(tester, repo, narrow: true);
      await showDelete(tester, 'staff-a');
      await tester.enterText(
        find.byKey(const ValueKey('employee-delete-reason')),
        'Pegawai telah keluar',
      );
      await confirm(tester);
      expect(
        find.textContaining('Penghapusan login belum selesai'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Tutup dan periksa daftar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tutup dan periksa daftar'));
      await tester.pumpAndSettle();
      final retry = find.byKey(const ValueKey('retry-delete-employee-staff-a'));
      await tester.scrollUntilVisible(
        retry,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(retry);
      await tester.pumpAndSettle();
      await capture(tester, 'employee-deletion-pending');
      expect(tester.takeException(), isNull);
      repo.pending = false;
      await tester.tap(retry);
      await tester.pumpAndSettle();
      await confirm(tester);
      expect(
        find.byKey(const ValueKey('retry-delete-employee-staff-a')),
        findsNothing,
      );
    },
  );
  testWidgets(
    'Double tap while deleting sends one request and blocks dismissal until response',
    (tester) async {
      final repo = PeopleRepository()..waiting = Completer<void>();
      await openPeople(tester, repo);
      await showDelete(tester, 'staff-a');
      await tester.enterText(
        find.byKey(const ValueKey('employee-delete-reason')),
        'Pegawai keluar',
      );
      final button = find.byKey(const ValueKey('confirm-delete-employee'));
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();
      expect(repo.deletions.length, 1);
      repo.waiting!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Hapus akun pegawai?'), findsNothing);
    },
  );
}

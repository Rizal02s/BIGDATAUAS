import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perona_pos/app_theme.dart';
import 'package:perona_pos/domain.dart';
import 'package:perona_pos/expense_data.dart';
import 'package:perona_pos/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_page_test.dart'
    show DemoRepository, capture, loadPreviewFonts, previewKey, pumpHome;

class ExpenseRepository extends DemoRepository {
  final records = <String, Json>{};
  final submissions = <Json>[];
  final periods = <Period>[];
  final pages = <int>[];
  bool failRead = false, lostResponse = false;
  Completer<void>? pending;
  ExpenseRepository() {
    accessRole = 'owner';
  }
  void seed({int count = 1}) {
    final today = jakarta(DateTime.now());
    for (var i = 0; i < count; i++) {
      records['cost-$i'] = {
        'id': 'cost-$i',
        'spent_on':
            '${today.year}-${today.month.toString().padLeft(2, '0')}-01',
        'title': 'Biaya ${i + 1}',
        'category': 'Bahan & peralatan',
        'amount': 25000,
        'method': 'Tunai',
        'from_drawer': true,
        'notes': 'Nota pembelian',
        'operator_name': 'Rizal',
        'voided_at': null,
      };
    }
  }

  @override
  Future<ExpenseReport> expenses(Period period, int page) async {
    periods.add(period);
    pages.add(page);
    if (failRead) {
      throw const PostgrestException(
        code: 'PGRST202',
        message: 'Missing expense_report',
      );
    }
    final all =
        records.values
            .where(
              (e) => period.contains(
                jakartaToUtc(DateTime.parse(e['spent_on'] as String)),
              ),
            )
            .toList();
    final active = all.where((e) => e['voided_at'] == null).toList();
    return ExpenseReport.fromJson({
      'total': active.fold<int>(0, (s, e) => s + money(e['amount'])),
      'count': active.length,
      'history_count': all.length,
      'drawer_cash': active
          .where((e) => e['from_drawer'] == true)
          .fold<int>(0, (s, e) => s + money(e['amount'])),
      'categories':
          active.isEmpty
              ? []
              : [
                {
                  'category': 'Bahan & peralatan',
                  'total': active.fold<int>(
                    0,
                    (s, e) => s + money(e['amount']),
                  ),
                },
              ],
      'rows': all.skip(page * 30).take(30).toList(),
    });
  }

  @override
  Future<void> recordExpense(Json expense) async {
    submissions.add(Json.from(expense));
    if (pending != null) await pending!.future;
    records.putIfAbsent(
      expense['id'] as String,
      () => {...expense, 'operator_name': 'Rizal', 'voided_at': null},
    );
    if (lostResponse) {
      lostResponse = false;
      throw const AuthException('Respons pengujian terputus');
    }
  }

  @override
  Future<void> voidExpense(String id, String reason) async {
    records[id] = {
      ...records[id]!,
      'voided_at': DateTime.now().toUtc().toIso8601String(),
      'void_reason': reason,
      'void_operator_name': 'Rizal',
    };
  }
}

Future<void> openExpenses(
  WidgetTester tester,
  ExpenseRepository repo, {
  bool narrow = false,
}) async {
  tester.view.physicalSize = Size(narrow ? 320 : 412, 892);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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
        home: ExpensesPage(repo: repo),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> press(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> fillExpense(WidgetTester tester, {String amount = '25000'}) async {
  await press(tester, find.byKey(const ValueKey('add-expense')));
  await tester.enterText(
    find.byKey(const ValueKey('expense-title')),
    'Beli cairan pembersih',
  );
  await tester.enterText(find.byKey(const ValueKey('expense-amount')), amount);
}

void main() {
  setUpAll(loadPreviewFonts);
  testWidgets(
    'Internal hub keeps five destinations and opens costs without replacing staff management',
    (tester) async {
      final repo = ExpenseRepository();
      await pumpHome(tester, repo, 'owner');
      expect(find.byType(NavigationDestination), findsNWidgets(5));
      expect(find.text('Pegawai'), findsNothing);
      await tester.tap(find.text('Internal'));
      await tester.pumpAndSettle();
      expect(repo.periods, isEmpty);
      expect(find.text('Pengeluaran usaha'), findsOneWidget);
      await capture(tester, 'internal-menu');
      await press(tester, find.byKey(const ValueKey('open-business-expenses')));
      expect(
        find.text('Belum ada pengeluaran pada periode ini.'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'Expense overview displays costs totals categories operator and source',
    (tester) async {
      final repo = ExpenseRepository()..seed();
      await openExpenses(tester, repo);
      expect(find.text('Total pengeluaran'), findsOneWidget);
      expect(find.text('Rp25.000'), findsWidgets);
      expect(find.text('Dicatat oleh Rizal'), findsOneWidget);
      expect(find.text('Tunai · Dari kas toko'), findsOneWidget);
      await capture(tester, 'business-expenses');
    },
  );
  testWidgets(
    'Save cash expense and choose earlier business date from calendar',
    (tester) async {
      final repo = ExpenseRepository();
      await openExpenses(tester, repo);
      await fillExpense(tester);
      await press(tester, find.byKey(const ValueKey('expense-date')));
      await tester.tap(find.text('1').last);
      await tester.tap(find.text('Pilih'));
      await tester.pumpAndSettle();
      await capture(tester, 'business-expense-form');
      await press(tester, find.byKey(const ValueKey('save-expense')));
      expect(repo.records.length, 1);
      final saved = repo.records.values.single;
      expect(saved['from_drawer'], true);
      expect(saved['amount'], 25000);
      expect(DateTime.parse(saved['spent_on'] as String).day, 1);
      expect(find.text('Beli cairan pembersih'), findsOneWidget);
    },
  );
  testWidgets(
    'Transfer never claims cash drawer; cancel and invalid amount do not save',
    (tester) async {
      final repo = ExpenseRepository();
      await openExpenses(tester, repo);
      await fillExpense(tester, amount: '0');
      await press(tester, find.byKey(const ValueKey('save-expense')));
      expect(repo.submissions, isEmpty);
      await tester.enterText(
        find.byKey(const ValueKey('expense-amount')),
        '35000',
      );
      await press(tester, find.byKey(const ValueKey('expense-method')));
      await tester.tap(find.text('Transfer').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('expense-from-drawer')), findsNothing);
      await press(tester, find.byKey(const ValueKey('save-expense')));
      expect(repo.records.values.single['method'], 'Transfer');
      expect(repo.records.values.single['from_drawer'], false);
      await press(tester, find.byKey(const ValueKey('add-expense')));
      await press(tester, find.text('Tutup'));
      expect(repo.records.length, 1);
    },
  );
  testWidgets(
    'Lost response retries same frozen ID without duplicate expense',
    (tester) async {
      final repo = ExpenseRepository()..lostResponse = true;
      await openExpenses(tester, repo);
      await fillExpense(tester);
      await press(tester, find.byKey(const ValueKey('save-expense')));
      expect(repo.records.length, 1);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('expense-title')))
            .enabled,
        false,
      );
      await press(tester, find.byKey(const ValueKey('save-expense')));
      expect(repo.submissions.length, 2);
      expect(repo.submissions[0], repo.submissions[1]);
      expect(repo.records.length, 1);
    },
  );
  testWidgets('Double tap while saving sends only one request', (tester) async {
    final repo = ExpenseRepository()..pending = Completer<void>();
    await openExpenses(tester, repo);
    await fillExpense(tester);
    final target = find.byKey(const ValueKey('save-expense'));
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pump();
    await tester.tap(target);
    await tester.pump();
    expect(repo.submissions.length, 1);
    repo.pending!.complete();
    await tester.pumpAndSettle();
    expect(repo.records.length, 1);
  });
  testWidgets(
    'Correction requires reason keeps history and removes expense from total',
    (tester) async {
      final repo = ExpenseRepository()..seed();
      await openExpenses(tester, repo);
      await press(tester, find.byKey(const ValueKey('correct-expense-cost-0')));
      await tester.enterText(
        find.byType(TextField).last,
        'Salah catat nominal',
      );
      await press(tester, find.text('Konfirmasi'));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Dikoreksi · Tidak dihitung'), findsOneWidget);
      expect(find.text('Rp0'), findsWidgets);
      expect(repo.records.length, 1);
    },
  );
  testWidgets(
    'Missing migration retries and large text on small phone has no overflow',
    (tester) async {
      final repo = ExpenseRepository()..failRead = true;
      await openExpenses(tester, repo, narrow: true);
      expect(find.textContaining('010_business_expenses.sql'), findsOneWidget);
      repo.failRead = false;
      await press(tester, find.text('Coba lagi'));
      await fillExpense(tester);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Expense list loads beyond thirty without dropping totals', (
    tester,
  ) async {
    final repo = ExpenseRepository()..seed(count: 31);
    await openExpenses(tester, repo);
    await tester.scrollUntilVisible(
      find.text('Muat lebih banyak'),
      600,
      scrollable: find.byType(Scrollable).first,
    );
    await press(tester, find.text('Muat lebih banyak'));
    expect(repo.pages.last, 1);
    await tester.scrollUntilVisible(
      find.text('Biaya 31'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Biaya 31'), findsOneWidget);
  });
  testWidgets(
    'Direct expense page blocks nonowners without requesting internal data',
    (tester) async {
      for (final role in ['admin', 'technician']) {
        final repo = ExpenseRepository()..accessRole = role;
        await openExpenses(tester, repo);
        expect(
          find.text('Pengeluaran usaha hanya untuk owner.'),
          findsOneWidget,
        );
        expect(repo.periods, isEmpty);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
    },
  );
  testWidgets(
    'Calendar period includes both dates and resets expense pagination',
    (tester) async {
      final repo = ExpenseRepository()..seed();
      await openExpenses(tester, repo);
      await press(tester, find.byKey(const ValueKey('expense-period')));
      await tester.tap(find.byTooltip('Switch to input'));
      await tester.pumpAndSettle();
      final month = jakarta(DateTime.now());
      final start =
          '${month.month.toString().padLeft(2, '0')}/01/${month.year}';
      final end = '${month.month.toString().padLeft(2, '0')}/02/${month.year}';
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), start);
      await tester.enterText(fields.at(1), end);
      await tester.tap(find.text('Pilih').last);
      await tester.pumpAndSettle();
      expect(
        jakarta(repo.periods.last.start),
        DateTime.utc(month.year, month.month, 1),
      );
      expect(
        jakarta(repo.periods.last.end),
        DateTime.utc(month.year, month.month, 3),
      );
      expect(repo.pages.last, 0);
      expect(find.text('Biaya 1'), findsOneWidget);
    },
  );
}

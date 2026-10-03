import 'package:flutter_test/flutter_test.dart';
import 'package:perona_pos/domain.dart';

Json line(int price, int labor, int qty) => {'price': price, 'labor_fee': labor, 'quantity': qty};
void main() {
  test('Dua Deep Clean dan satu ODS: nilai order 110000, upah 40000', () {
    final t = Totals.fromItems([line(30000, 10000, 2), line(50000, 20000, 1)], 0);
    expect(t.revenue, 110000); expect(t.labor, 40000); expect(t.contribution, 70000);
  });
  test('Diskon tidak mengurangi upah', () {
    final t = Totals.fromItems([line(30000, 10000, 2), line(50000, 20000, 1)], 10000);
    expect(t.revenue, 100000); expect(t.labor, 40000); expect(t.contribution, 60000);
  });
  test('Kid Shoes ongkos 7500 tersimpan tepat', () {
    expect(Totals.fromItems([line(20000, 7500, 3)], 0).labor, 22500);
  });
  test('Diskon di atas bruto ditolak', () {
    expect(() => Totals.fromItems([line(30000, 10000, 1)], 30001), throwsArgumentError);
  });
  test('Diskon negatif ditolak', () {
    expect(() => Totals.fromItems([line(30000, 10000, 1)], -1), throwsArgumentError);
  });
  test('Jumlah nol dan lebih dari 999 ditolak', () {
    expect(() => Totals.fromItems([line(30000, 10000, 0)], 0), throwsArgumentError);
    expect(() => Totals.fromItems([line(30000, 10000, 1000)], 0), throwsArgumentError);
  });
  test('Ongkos kosong tidak dianggap nol', () {
    expect(() => Totals.fromItems([{'price': 30000, 'labor_fee': null, 'quantity': 1}], 0), throwsArgumentError);
  });
  test('Harian WIB tidak mengikuti zona waktu HP', () {
    final p = Period.forDate(DateTime(2026, 10, 2), 'day');
    expect(p.start, DateTime.utc(2026, 10, 1, 17));
    expect(p.end, DateTime.utc(2026, 10, 2, 17));
    expect(p.contains(DateTime.utc(2026, 10, 1, 17)), isTrue);
    expect(p.contains(DateTime.utc(2026, 10, 2, 17)), isFalse);
  });
  test('Desember berganti tahun dengan benar', () {
    final p = Period.forDate(DateTime(2026, 12, 15), 'month');
    expect(p.start, DateTime.utc(2026, 11, 30, 17));
    expect(p.end, DateTime.utc(2026, 12, 31, 17));
  });
  test('Februari tahun kabisat dan periode tahunan', () {
    final p = Period.forDate(DateTime(2028, 2, 1), 'month');
    expect(p.end.difference(p.start).inDays, 29);
    final y = Period.forDate(DateTime(2028, 6, 1), 'year');
    expect(y.end.difference(y.start).inDays, 366);
  });
}

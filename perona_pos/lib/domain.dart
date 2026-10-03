typedef Json = Map<String, dynamic>;

// Semua nilai uang berupa rupiah bulat, bukan floating point.
int money(dynamic value) => (value as num?)?.toInt() ?? 0;
DateTime jakarta(DateTime value) => value.toUtc().add(const Duration(hours: 7));

class Period {
  final DateTime start;
  final DateTime end;
  const Period(this.start, this.end);
  factory Period.forDate(DateTime date, String kind) {
    DateTime local(int y, int m, int d) =>
        DateTime.utc(y, m, d).subtract(const Duration(hours: 7));
    switch (kind) {
      case 'year':
        return Period(local(date.year, 1, 1), local(date.year + 1, 1, 1));
      case 'month':
        return Period(
          local(date.year, date.month, 1),
          local(date.year, date.month + 1, 1),
        );
      default:
        return Period(
          local(date.year, date.month, date.day),
          local(date.year, date.month, date.day + 1),
        );
    }
  }
  bool contains(DateTime date) => !date.isBefore(start) && date.isBefore(end);
}

class Totals {
  final int gross;
  final int discount;
  final int labor;
  const Totals(this.gross, this.discount, this.labor);
  int get revenue => gross - discount;
  // Ini kontribusi setelah upah, belum dikurangi bahan, sewa, dll.
  int get contribution => revenue - labor;
  factory Totals.fromItems(List<Json> items, int discount) {
    var gross = 0;
    var labor = 0;
    for (final item in items) {
      final quantity = money(item['quantity']);
      if (quantity < 1 || quantity > 999) {
        throw ArgumentError('Jumlah harus 1–999.');
      }
      if (item['labor_fee'] == null) {
        throw ArgumentError('Tarif ongkos belum ditetapkan.');
      }
      final price = money(item['price']);
      final fee = money(item['labor_fee']);
      if (price < 0 || fee < 0) {
        throw ArgumentError('Tarif tidak boleh negatif.');
      }
      gross += price * quantity;
      labor += fee * quantity;
    }
    if (discount < 0 || discount > gross) {
      throw ArgumentError('Diskon melebihi nilai layanan.');
    }
    return Totals(gross, discount, labor);
  }
}

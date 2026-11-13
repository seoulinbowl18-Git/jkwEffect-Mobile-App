import 'package:intl/intl.dart';

final _num = NumberFormat.decimalPattern('id_ID');
final _date = DateFormat('d MMM yyyy', 'id_ID');

/// `Rp 1.250.000`
String rp(num? n) => 'Rp ${_num.format(n ?? 0)}';

/// `1.250.000`
String fmtNum(num? n) => _num.format(n ?? 0);

/// `3 Nov 2026`
String fmtDate(String? iso) {
  final d = DateTime.tryParse(iso ?? '');
  return d == null ? '-' : _date.format(d.toLocal());
}

/// Sisa hari hingga [iso] (minimal 0).
int daysLeft(String? iso) {
  final d = DateTime.tryParse(iso ?? '');
  if (d == null) return 0;
  final diff = d.difference(DateTime.now()).inHours / 24;
  return diff <= 0 ? 0 : diff.ceil();
}

// Pengaman acuan desain baku: nilai visual (warna, ukuran font, radius) hanya
// boleh berasal dari lib/core/theme.dart (AppTheme / AppSpace / AppRadius /
// Theme.of(context)). Pengecualian yang disengaja ditandai `// design-ok: alasan`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _rules = <String, RegExp>{
  'warna literal Color(0x…)': RegExp(r'Color\(0x'),
  'warna langsung Colors.x (pakai colorScheme / AppTheme)': RegExp(r'Colors\.(?!transparent\b)[a-z]'),
  'fontSize manual (pakai Theme.of(context).textTheme)': RegExp(r'fontSize:'),
  'radius angka (pakai AppRadius)': RegExp(r'Radius\.circular\(\s*[0-9]'),
};

void main() {
  test('semua halaman memakai token desain dari theme.dart', () {
    final violations = <String>[];
    final files = Directory('lib').listSync(recursive: true).whereType<File>().where(
          (f) => f.path.endsWith('.dart') && !f.path.replaceAll(r'\', '/').endsWith('lib/core/theme.dart'),
        );
    for (final f in files) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.contains('// design-ok:') || line.trimLeft().startsWith('//')) continue;
        _rules.forEach((rule, re) {
          if (re.hasMatch(line)) violations.add('${f.path}:${i + 1}  [$rule]  ${line.trim()}');
        });
      }
    }
    expect(violations, isEmpty, reason: 'Nilai visual di luar token desain:\n${violations.join('\n')}');
  });
}

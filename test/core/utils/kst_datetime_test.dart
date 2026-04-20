import 'package:a_and_i_admin_web_serivce/core/utils/kst_datetime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('KST datetime helpers', () {
    test('parses API ISO values with nanosecond fractions', () {
      expect(
        apiIsoToDisplayKst('2026-04-15T01:04:38.276808658+09:00'),
        '2026-04-15 01:04',
      );
      expect(
        apiIsoToDatetimeLocalKst('2026-04-15T01:04:38.276808658+09:00'),
        '2026-04-15T01:04',
      );
    });

    test('converts UTC API ISO values to KST wall-clock values', () {
      expect(
        apiIsoToDisplayKst('2026-04-14T16:04:38.276808658Z'),
        '2026-04-15 01:04',
      );
    });

    test('serializes datetime-local KST values for the API', () {
      expect(
        datetimeLocalKstToApiIso('2026-04-15T01:04'),
        '2026-04-15T01:04:00+09:00',
      );
    });

    test('keeps assignment edit values stable across a KST round trip', () {
      final editValue = apiIsoToDatetimeLocalKst('2026-04-20T09:00:00+09:00');

      expect(editValue, '2026-04-20T09:00');
      expect(datetimeLocalKstToApiIso(editValue), '2026-04-20T09:00:00+09:00');
    });
  });
}

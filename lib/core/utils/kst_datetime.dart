const int _kstOffsetMinutes = 9 * 60;

final RegExp _apiIsoPattern = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})(?::(\d{2})(?:\.(\d{1,6}))?)?(Z|[+-]\d{2}(?::?\d{2})?)?$',
);
final RegExp _datetimeLocalPattern = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})$',
);

String apiIsoToDatetimeLocalKst(String iso) {
  final trimmed = iso.trim();
  if (trimmed.isEmpty) return '';

  final dateTime = _parseApiIsoAsKstWallClock(trimmed);
  return _formatWallClock(dateTime, separator: 'T');
}

String apiIsoToDisplayKst(String iso) {
  final trimmed = iso.trim();
  if (trimmed.isEmpty) return '';

  final dateTime = _parseApiIsoAsKstWallClock(trimmed);
  return _formatWallClock(dateTime, separator: ' ');
}

String datetimeLocalKstToApiIso(String value) {
  final match = _datetimeLocalPattern.firstMatch(value.trim());
  if (match == null) {
    throw FormatException('Invalid datetime-local KST value: $value');
  }

  return '${match.group(1)}-${match.group(2)}-${match.group(3)}T'
      '${match.group(4)}:${match.group(5)}:00+09:00';
}

DateTime? tryParseDatetimeLocalKst(String value) {
  final match = _datetimeLocalPattern.firstMatch(value.trim());
  if (match == null) return null;

  return DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
    int.parse(match.group(4)!),
    int.parse(match.group(5)!),
  );
}

String formatDatetimeLocalKst(DateTime value) {
  return _formatWallClock(value, separator: 'T');
}

DateTime _parseApiIsoAsKstWallClock(String iso) {
  final match = _apiIsoPattern.firstMatch(iso.trim());
  if (match == null) {
    throw FormatException('Invalid API ISO datetime: $iso');
  }

  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final hour = int.parse(match.group(4)!);
  final minute = int.parse(match.group(5)!);
  final second = int.tryParse(match.group(6) ?? '') ?? 0;
  final fraction = (match.group(7) ?? '').padRight(6, '0');
  final microseconds = fraction.isEmpty ? 0 : int.parse(fraction);
  final milliseconds = microseconds ~/ 1000;
  final remainingMicroseconds = microseconds % 1000;
  final offsetMinutes = _parseOffsetMinutes(match.group(8));

  final utcDateTime = DateTime.utc(
    year,
    month,
    day,
    hour,
    minute,
    second,
    milliseconds,
    remainingMicroseconds,
  ).subtract(Duration(minutes: offsetMinutes));

  return utcDateTime.add(const Duration(minutes: _kstOffsetMinutes));
}

int _parseOffsetMinutes(String? offsetToken) {
  if (offsetToken == null || offsetToken.isEmpty) {
    return _kstOffsetMinutes;
  }
  if (offsetToken == 'Z') {
    return 0;
  }

  final sign = offsetToken.startsWith('-') ? -1 : 1;
  final body = offsetToken.substring(1).replaceAll(':', '');
  final hours = int.parse(body.substring(0, 2));
  final minutes = body.length >= 4 ? int.parse(body.substring(2, 4)) : 0;
  return sign * (hours * 60 + minutes);
}

String _formatWallClock(DateTime value, {required String separator}) {
  final yyyy = value.year.toString().padLeft(4, '0');
  final mm = value.month.toString().padLeft(2, '0');
  final dd = value.day.toString().padLeft(2, '0');
  final hh = value.hour.toString().padLeft(2, '0');
  final min = value.minute.toString().padLeft(2, '0');
  return '$yyyy-$mm-$dd$separator$hh:$min';
}

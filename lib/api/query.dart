import '../utils/time_utils.dart';

/// Formatters for MOTIS query parameters.
///
/// These live in their own file because the API is not self-consistent about
/// coordinates and silently ignores parameters it does not recognise: a value
/// in the wrong shape comes back as HTTP 400 at best and a quietly wrong route
/// at worst, so every call site goes through these helpers and
/// `test/api/query_test.dart` pins the formats down.
class Q {
  const Q._();

  /// Coordinate for every endpoint except the two named on
  /// [latLonSemicolon]: `lat,lon`.
  ///
  /// Covers `/plan`, `/geocode`, `/map/*`, `/one-to-all` and `/rentals`.
  static String latLonComma(double lat, double lon) =>
      '${_coord(lat)},${_coord(lon)}';

  /// Coordinate for `/one-to-many` and `/one-to-many-intermodal`: `lat;lon`.
  ///
  /// Only these two take the semicolon form; they reject the comma form with
  /// `"<value> is not a valid geo coordinate"`.
  ///
  /// Do not reach for this elsewhere. `/rentals` accepts semicolons without
  /// complaint and then returns providers from the wrong part of the country,
  /// so the mistake shows up as bad data rather than an error.
  static String latLonSemicolon(double lat, double lon) =>
      '${_coord(lat)};${_coord(lon)}';

  /// Comma-joined list, the encoding MOTIS uses for every array parameter
  /// (`explode: false` throughout the spec).
  ///
  /// Returns null for a null or empty list so the parameter is dropped rather
  /// than sent as an empty string, which MOTIS treats as a real value.
  static String? csv(Iterable<String>? values) {
    if (values == null) return null;
    final list = values.toList(growable: false);
    if (list.isEmpty) return null;
    return list.join(',');
  }

  /// Comma-joined list of numbers, e.g. `viaMinimumStay`.
  static String? csvNum(Iterable<num>? values) =>
      csv(values?.map((v) => number(v)!));

  static String? boolean(bool? value) => value?.toString();

  /// Whole seconds, the unit MOTIS uses for every duration parameter.
  static String? seconds(Duration? value) => value?.inSeconds.toString();

  static String? minutes(Duration? value) => value?.inMinutes.toString();

  static String? integer(int? value) => value?.toString();

  /// Number without a trailing `.0`, so integral values read as integers on
  /// the wire.
  static String? number(num? value) {
    if (value == null) return null;
    if (value is int) return value.toString();
    if (value == value.roundToDouble() && value.abs() < 1e15) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  /// Timestamp with millisecond precision, as `/stoptimes` and `/map/trips`
  /// expect. Reuses the app's existing formatter.
  static String? dateTime(DateTime? value) =>
      value == null ? null : formatIso8601Millis(value);

  /// Six decimal places is ~0.1 m — more than enough, and it keeps URLs short
  /// and cache keys stable.
  static String _coord(double value) => value.toStringAsFixed(6);
}

import 'json.dart';

/// A half-open time interval, active at `t` when `start <= t < end`.
///
/// Either bound may be absent, meaning the interval extends to minus or plus
/// infinity in that direction.
class TimeRange {
  const TimeRange({this.start, this.end});

  final DateTime? start;
  final DateTime? end;

  factory TimeRange.fromJson(Map<String, dynamic> json) =>
      TimeRange(start: asDateTime(json['start']), end: asDateTime(json['end']));

  bool contains(DateTime time) {
    if (start != null && time.isBefore(start!)) return false;
    if (end != null && !time.isBefore(end!)) return false;
    return true;
  }
}

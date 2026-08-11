import 'package:flutter/widgets.dart';

String formatTime(DateTime? dateTime, {String nullPlaceholder = '-'}) {
  if (dateTime == null) return nullPlaceholder;

  final local = dateTime.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// Whether [a] and [b] fall in the same local wall-clock minute.
bool isSameMinute(DateTime a, DateTime b) {
  final aLocal = a.toLocal();
  final bLocal = b.toLocal();
  return aLocal.year == bLocal.year &&
      aLocal.month == bLocal.month &&
      aLocal.day == bLocal.day &&
      aLocal.hour == bLocal.hour &&
      aLocal.minute == bLocal.minute;
}

Duration? computeDelay(
  DateTime? scheduledTime,
  DateTime actualTime, {
  Duration threshold = const Duration(minutes: 1),
}) {
  if (scheduledTime == null) return null;
  final diff = actualTime.difference(scheduledTime);
  if (diff.inSeconds.abs() < threshold.inSeconds) return null;
  return diff;
}

String formatDelay(Duration delay) {
  final isNegative = delay.isNegative;
  final totalMinutes = delay.inMinutes.abs();
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  final buffer = <String>[];
  if (hours > 0) buffer.add('${hours}h');
  if (minutes > 0 || buffer.isEmpty) buffer.add('${minutes}m');
  final sign = isNegative ? '-' : '+';
  return '$sign${buffer.join(' ')}';
}

const List<String> _weekdayNames = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

const List<String> _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Day label for a date the user is looking at in relation to now:
/// 'Today', 'Tomorrow', a weekday name within the coming week, or a
/// short date beyond that.
String formatRelativeDay(DateTime dateTime, {DateTime? now}) {
  final local = dateTime.toLocal();
  final reference = (now ?? DateTime.now()).toLocal();

  final day = DateTime(local.year, local.month, local.day);
  final today = DateTime(reference.year, reference.month, reference.day);
  final dayDifference = day.difference(today).inDays;

  if (dayDifference == 0) return 'Today';
  if (dayDifference == 1) return 'Tomorrow';
  if (dayDifference == -1) return 'Yesterday';
  if (dayDifference > 1 && dayDifference < 7) {
    return _weekdayNames[local.weekday - 1];
  }
  return '${local.day} ${_monthNames[local.month - 1]}';
}

String formatIso8601Millis(DateTime dateTime) {
  final utc = dateTime.toUtc();
  final base = utc.toIso8601String();
  final dot = base.indexOf('.');
  if (dot == -1) {
    return base;
  }
  final millis = utc.millisecond.toString().padLeft(3, '0');
  return '${base.substring(0, dot)}.${millis}Z';
}

Color delayColor(Duration delay) {
  return delay.isNegative ? const Color(0xFF2E7D32) : const Color(0xFFB26A00);
}

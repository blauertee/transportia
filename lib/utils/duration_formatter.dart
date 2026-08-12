/// Metres in a kilometre.
const double kMetresPerKilometre = 1000;

/// A distance in metres as kilometres, the only unit the app ever prints one
/// in. [decimals] is two where the number stands alone and one where it sits
/// in a chip beside other figures.
String formatDistanceKm(double metres, {int decimals = 2}) =>
    '${(metres / kMetresPerKilometre).toStringAsFixed(decimals)} km';

String formatDuration(int seconds) {
  if (seconds < 0) {
    return 'N/A';
  }

  int hours = seconds ~/ 3600;
  int minutes = (seconds % 3600) ~/ 60;

  if (hours > 0) {
    return '${hours}h ${minutes}m';
  } else {
    return '${minutes}m';
  }
}

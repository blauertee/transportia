import 'enums.dart';
import 'json.dart';
import 'time_range.dart';

/// A GTFS-RT service alert attached to a leg, a stop or a stop time.
class Alert {
  const Alert({
    this.code,
    this.communicationPeriod = const [],
    this.impactPeriod = const [],
    this.cause,
    this.causeDetail,
    this.effect,
    this.effectDetail,
    this.url,
    this.headerText,
    this.descriptionText,
    this.ttsHeaderText,
    this.ttsDescriptionText,
    this.severityLevel,
    this.imageUrl,
    this.imageMediaType,
    this.imageAlternativeText,
  });

  /// Operator-defined identifier, not unique across feeds.
  final int? code;

  /// When the alert should be shown to riders.
  final List<TimeRange> communicationPeriod;

  /// When the disruption itself is in effect.
  final List<TimeRange> impactPeriod;

  final AlertCause? cause;
  final String? causeDetail;
  final AlertEffect? effect;
  final String? effectDetail;
  final String? url;
  final String? headerText;
  final String? descriptionText;

  /// Text-to-speech variants, used in place of the display text by readers.
  final String? ttsHeaderText;
  final String? ttsDescriptionText;

  final AlertSeverityLevel? severityLevel;
  final String? imageUrl;
  final String? imageMediaType;
  final String? imageAlternativeText;

  /// True when the alert carries something worth showing.
  bool get hasText =>
      (headerText != null && headerText!.isNotEmpty) ||
      (descriptionText != null && descriptionText!.isNotEmpty);

  /// True when [time] falls inside any impact period, or when no impact period
  /// is given (an alert without one is treated as always in effect).
  bool isInEffectAt(DateTime time) =>
      impactPeriod.isEmpty || impactPeriod.any((range) => range.contains(time));

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      code: asInt(json['code']),
      communicationPeriod: asList(
        json['communicationPeriod'],
        TimeRange.fromJson,
      ),
      impactPeriod: asList(json['impactPeriod'], TimeRange.fromJson),
      cause: AlertCause.fromWire(json['cause']),
      causeDetail: asString(json['causeDetail']),
      effect: AlertEffect.fromWire(json['effect']),
      effectDetail: asString(json['effectDetail']),
      url: asString(json['url']),
      headerText: asString(json['headerText']),
      descriptionText: asString(json['descriptionText']),
      ttsHeaderText: asString(json['ttsHeaderText']),
      ttsDescriptionText: asString(json['ttsDescriptionText']),
      severityLevel: AlertSeverityLevel.fromWire(json['severityLevel']),
      imageUrl: asString(json['imageUrl']),
      imageMediaType: asString(json['imageMediaType']),
      imageAlternativeText: asString(json['imageAlternativeText']),
    );
  }
}

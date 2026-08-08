import 'json.dart';

/// Vehicle category of a leg, e.g. `IC` / `InterCity`.
///
/// Populated from NeTEx datasets; GTFS feeds do not carry it by default.
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.shortName,
  });

  final String id;
  final String name;
  final String shortName;

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: asString(json['id']) ?? '',
    name: asString(json['name']) ?? '',
    shortName: asString(json['shortName']) ?? '',
  );
}

/// Per-platform links for buying a ticket for a leg.
class TicketUrls {
  const TicketUrls({this.web, this.android, this.ios});

  final String? web;
  final String? android;
  final String? ios;

  bool get isEmpty => web == null && android == null && ios == null;

  factory TicketUrls.fromJson(Map<String, dynamic> json) => TicketUrls(
    web: asString(json['web']),
    android: asString(json['android']),
    ios: asString(json['ios']),
  );
}

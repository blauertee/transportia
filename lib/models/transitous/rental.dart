import 'enums.dart';
import 'json.dart';

/// Vehicle-sharing details attached to a `RENTAL` leg.
class Rental {
  const Rental({
    required this.providerId,
    required this.providerGroupId,
    required this.systemId,
    this.systemName,
    this.url,
    this.color,
    this.stationName,
    this.fromStationName,
    this.toStationName,
    this.rentalUriAndroid,
    this.rentalUriIOS,
    this.rentalUriWeb,
    this.formFactor,
    this.propulsionType,
    this.returnConstraint,
  });

  final String providerId;
  final String providerGroupId;

  /// GBFS system identifier of the provider.
  final String systemId;
  final String? systemName;

  /// Provider home page.
  final String? url;

  /// Brand colour as a CSS hex string, for map and badge tinting.
  final String? color;

  /// Station the vehicle is at, for station-based systems.
  final String? stationName;
  final String? fromStationName;
  final String? toStationName;

  /// Deep links into the provider's app, preferred over [url] when present.
  final String? rentalUriAndroid;
  final String? rentalUriIOS;
  final String? rentalUriWeb;

  final RentalFormFactor? formFactor;
  final RentalPropulsionType? propulsionType;

  /// Where the vehicle may be returned; drives whether a trip is one-way.
  final RentalReturnConstraint? returnConstraint;

  factory Rental.fromJson(Map<String, dynamic> json) {
    return Rental(
      providerId: asString(json['providerId']) ?? '',
      providerGroupId: asString(json['providerGroupId']) ?? '',
      systemId: asString(json['systemId']) ?? '',
      systemName: asString(json['systemName']),
      url: asString(json['url']),
      color: asString(json['color']),
      stationName: asString(json['stationName']),
      fromStationName: asString(json['fromStationName']),
      toStationName: asString(json['toStationName']),
      rentalUriAndroid: asString(json['rentalUriAndroid']),
      rentalUriIOS: asString(json['rentalUriIOS']),
      rentalUriWeb: asString(json['rentalUriWeb']),
      formFactor: RentalFormFactor.fromWire(json['formFactor']),
      propulsionType: RentalPropulsionType.fromWire(json['propulsionType']),
      returnConstraint: RentalReturnConstraint.fromWire(
        json['returnConstraint'],
      ),
    );
  }
}

/// Vehicle category offered by a rental provider.
class RentalVehicleType {
  const RentalVehicleType({
    required this.id,
    this.name,
    this.formFactor,
    this.propulsionType,
    this.returnConstraint,
    this.returnConstraintGuessed = false,
  });

  final String id;
  final String? name;
  final RentalFormFactor? formFactor;
  final RentalPropulsionType? propulsionType;
  final RentalReturnConstraint? returnConstraint;

  /// True when MOTIS inferred the return constraint rather than reading it
  /// from the provider's feed, so it may be wrong.
  final bool returnConstraintGuessed;

  factory RentalVehicleType.fromJson(Map<String, dynamic> json) {
    return RentalVehicleType(
      id: asString(json['id']) ?? '',
      name: asString(json['name']),
      formFactor: RentalFormFactor.fromWire(json['formFactor']),
      propulsionType: RentalPropulsionType.fromWire(json['propulsionType']),
      returnConstraint: RentalReturnConstraint.fromWire(
        json['returnConstraint'],
      ),
      returnConstraintGuessed: asBool(json['returnConstraintGuessed']) ?? false,
    );
  }
}

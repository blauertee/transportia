import '../../models/itinerary_response.dart';
import '../params/plan_params.dart';
import '../transitous_client.dart';
import '../transitous_endpoint.dart';

/// `/plan` — journey planning.
class PlanEndpoint {
  const PlanEndpoint._();

  static Future<ItineraryResponse> plan(
    PlanParams params, {
    TransitousClient? client,
  }) {
    return (client ?? TransitousClient.instance).get(
      TransitousEndpoint.plan,
      params.toQuery(),
      (json) => ItineraryResponse.fromJson(json as Map<String, dynamic>),
    );
  }
}

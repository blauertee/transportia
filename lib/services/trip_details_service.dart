import '../api/endpoints/trip_endpoint.dart';
import '../models/itinerary.dart';

class TripDetailsService {
  static Future<Itinerary> fetchTripDetails({required String tripId}) =>
      TripEndpoint.trip(tripId: tripId);
}

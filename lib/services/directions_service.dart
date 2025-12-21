import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Service untuk berinteraksi dengan Google Directions API
class DirectionsService {
  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/directions/json';

  static const String _apiKey = 'AIzaSyDelfYcbxnCJKF5X56clemyFIZbAQKI4Oo';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  /// Mendapatkan rute dari origin ke destination
  /// Returns: Map dengan 'distance' (dalam km), 'duration' (dalam detik), dan 'polylinePoints'
  Future<Map<String, dynamic>?> getDirections({
    required LatLng origin,
    required LatLng destination,
  }) async {
    print(
        'Getting directions from ${origin.latitude},${origin.longitude} to ${destination.latitude},${destination.longitude}');

    try {
      final response = await _dio.get(
        _baseUrl,
        queryParameters: {
          'origin': '${origin.latitude},${origin.longitude}',
          'destination': '${destination.latitude},${destination.longitude}',
          'mode': 'driving', // Bisa diubah ke: walking, bicycling, transit
          'key': _apiKey,
          'language': 'id', // Bahasa Indonesia
        },
      );

      print('Directions API Status Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data;
        print('Directions API Status: ${data['status']}');

        // Check status dari API
        if (data['status'] == 'OK') {
          final route = data['routes'][0];
          final leg = route['legs'][0];

          // Ambil informasi jarak dan durasi
          final distanceInMeters = leg['distance']['value'] as int;
          final durationInSeconds = leg['duration']['value'] as int;
          final distanceInKm = distanceInMeters / 1000.0;

          print('Route found:');
          print('Distance: ${leg['distance']['text']}');
          print('Duration: ${leg['duration']['text']}');

          // Decode polyline untuk menampilkan rute di map
          final encodedPolyline =
              route['overview_polyline']['points'] as String;
          final polylinePoints = _decodePolyline(encodedPolyline);

          print('   Polyline points: ${polylinePoints.length}');

          return {
            'distance': distanceInKm,
            'duration': durationInSeconds,
            'polylinePoints': polylinePoints,
            'distanceText': leg['distance']['text'],
            'durationText': leg['duration']['text'],
          };
        } else {
          // API returned error status
          print('Directions API Error: ${data['status']}');
          if (data['error_message'] != null) {
            print('Error message: ${data['error_message']}');
          }

          return null;
        }
      } else {
        print('HTTP Error: ${response.statusCode}');
        return null;
      }
    } on DioException catch (e) {
      print('Dio Error: ${e.message}');
      print('Dio Error Type: ${e.type}');

      if (e.response != null) {
        print('Response status: ${e.response?.statusCode}');
        print('Response data: ${e.response?.data}');
      }

      // Handle specific error types
      if (e.type == DioExceptionType.connectionTimeout) {
        print('Connection timeout');
      } else if (e.type == DioExceptionType.receiveTimeout) {
        print('Receive timeout');
      } else if (e.type == DioExceptionType.connectionError) {
        print('No internet connection');
      }

      return null;
    } catch (e) {
      print('Unexpected error getting directions: $e');
      return null;
    }
  }

  /// Decode polyline string dari Google Maps API
  /// Reference: https://developers.google.com/maps/documentation/utilities/polylinealgorithm
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(
        lat / 1E5,
        lng / 1E5,
      ));
    }

    return points;
  }

  /// Test koneksi ke Directions API
  Future<bool> testConnection() async {
    print('Testing Directions API connection...');

    try {
      final testResult = await getDirections(
        origin: const LatLng(-7.4297, 109.2401), // Purwokerto
        destination: const LatLng(-7.4397, 109.2501), // Nearby
      );

      if (testResult != null) {
        print('Directions API test successful!');
        return true;
      } else {
        print('Directions API test failed - returned null');
        return false;
      }
    } catch (e) {
      print('Directions API test failed with error: $e');
      return false;
    }
  }
}

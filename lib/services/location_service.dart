import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class LocationResult {
  const LocationResult({this.position, this.error, this.isApproximate = false});

  final LatLng? position;
  final String? error;

  /// `true` quando la posizione arriva dalla geolocalizzazione via IP.
  final bool isApproximate;
}

/// Rileva la posizione con il GPS del browser e, se non disponibile,
/// ripiega su una stima basata sull'indirizzo IP.
class LocationService {
  Future<LocationResult> getCurrentLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever) {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 7),
          ),
        );
        return LocationResult(
          position: LatLng(position.latitude, position.longitude),
        );
      }
    } catch (e) {
      debugPrint('GPS geolocation failed: $e');
    }

    try {
      final response = await http
          .get(Uri.parse('https://ipwho.is/'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          final lat = (data['latitude'] as num?)?.toDouble();
          final lng = (data['longitude'] as num?)?.toDouble();
          if (lat != null && lng != null) {
            return LocationResult(
              position: LatLng(lat, lng),
              isApproximate: true,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('ipwho.is fallback failed: $e');
    }

    try {
      final response = await http
          .get(Uri.parse('https://ipapi.co/json/'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final lat = (data['latitude'] as num?)?.toDouble();
        final lng = (data['longitude'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          return LocationResult(position: LatLng(lat, lng), isApproximate: true);
        }
      }
    } catch (e) {
      debugPrint('ipapi.co fallback failed: $e');
    }

    return const LocationResult(
      error: "Impossibile rilevare la posizione. Tocca l'icona del lucchetto 🔒 "
          "nella barra dell'indirizzo del browser e consenti la \"Posizione\".",
    );
  }
}

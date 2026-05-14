import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

class LocationManager {
  static final LocationManager _instance = LocationManager._internal();
  factory LocationManager() => _instance;
  LocationManager._internal();

  StreamSubscription<Position>? _positionSubscription;
  Position? _lastKnownPosition;

  Position? get lastKnownPosition => _lastKnownPosition;

  Future<bool> checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) return false;

    return true;
  }

  Future<Position?> getCurrentPosition() async {
    if (!await checkPermission()) return null;
    
    try {
      _lastKnownPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return _lastKnownPosition;
    } catch (e) {
      debugPrint('LocationManager: Error getting position: $e');
      return null;
    }
  }

  void startListening(Function(Position) onLocationChanged) async {
    if (!await checkPermission()) return;

    await stopListening();

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Only update if moved 10 meters
      ),
    ).listen((Position position) {
      _lastKnownPosition = position;
      onLocationChanged(position);
    });
  }

  Future<void> stopListening() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class WeatherService extends ChangeNotifier {
  final String apiKey = '35f9d4b83374a188b383c7f70b10d233';
  final String baseUrl = 'https://api.openweathermap.org/data/2.5';
  final String geoUrl = 'https://api.openweathermap.org/geo/1.0';
  
  Map<String, dynamic>? currentWeather;
  List<dynamic>? forecast;
  bool isLoading = false;
  String? error;

  Future<List<Map<String, dynamic>>> getCitySuggestions(String query) async {
    if (query.length < 2) return [];

    try {
      // First, try to get Egyptian cities specifically
      final egyptResponse = await http.get(
        Uri.parse('$geoUrl/direct?q=$query,EG&limit=5&appid=$apiKey')
      ).timeout(const Duration(seconds: 5));

      // Then get general results
      final globalResponse = await http.get(
        Uri.parse('$geoUrl/direct?q=$query&limit=10&appid=$apiKey')
      ).timeout(const Duration(seconds: 5));

      List<Map<String, dynamic>> suggestions = [];

      if (egyptResponse.statusCode == 200) {
        final List<dynamic> egyptData = json.decode(egyptResponse.body);
        suggestions.addAll(egyptData.map((city) => {
          'name': city['name'],
          'country': city['country'],
          'state': city['state'],
          'lat': city['lat'],
          'lon': city['lon'],
          'isEgyptian': true,
        }));
      }

      if (globalResponse.statusCode == 200) {
        final List<dynamic> globalData = json.decode(globalResponse.body);
        for (var city in globalData) {
          // Skip if it's already in suggestions (Egyptian results)
          if (!suggestions.any((s) => 
              s['name'] == city['name'] && 
              s['country'] == city['country'] &&
              s['lat'] == city['lat'] &&
              s['lon'] == city['lon']
          )) {
            suggestions.add({
              'name': city['name'],
              'country': city['country'],
              'state': city['state'],
              'lat': city['lat'],
              'lon': city['lon'],
              'isEgyptian': city['country'] == 'EG',
            });
          }
        }
      }

      // Sort suggestions to prioritize Egyptian cities
      suggestions.sort((a, b) {
        if (a['isEgyptian'] == b['isEgyptian']) {
          // If both are Egyptian or both are not, sort alphabetically
          return (a['name'] as String).compareTo(b['name'] as String);
        }
        // Put Egyptian cities first
        return a['isEgyptian'] ? -1 : 1;
      });

      // Limit to 5 results
      return suggestions.take(5).toList();
    } catch (e) {
      debugPrint('Error fetching suggestions: $e');
    }
    return [];
  }

  Future<void> searchCityByCoordinates(double lat, double lon) async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();
      await getWeatherData(lat, lon);
    } catch (e) {
      error = e.toString().replaceAll('Exception: ', '');
      currentWeather = null;
      forecast = null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> searchCity(String city) async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();

      final response = await http.get(
        Uri.parse('$baseUrl/weather?q=$city&appid=$apiKey&units=metric')
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final weatherData = json.decode(response.body);
        final lat = weatherData['coord']['lat'];
        final lon = weatherData['coord']['lon'];
        await getWeatherData(lat, lon);
      } else if (response.statusCode == 404) {
        throw Exception('City not found. Please check the spelling and try again.');
      } else {
        throw Exception('Failed to fetch weather data for $city');
      }
    } catch (e) {
      error = e.toString().replaceAll('Exception: ', '');
      currentWeather = null;
      forecast = null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> getCurrentLocation() async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          throw Exception('Please enable location services in your device settings to get weather information for your area.');
        }
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission is required to get weather information for your area.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied. Please enable them in your device settings to use this app.');
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 5),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Location request timed out. Please try again.'),
      );

      await getWeatherData(position.latitude, position.longitude);
    } catch (e) {
      error = e.toString().replaceAll('Exception: ', '');
      currentWeather = null;
      forecast = null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> getWeatherData(double lat, double lon) async {
    final client = http.Client();
    try {
      final currentWeatherResponse = await client
          .get(Uri.parse('$baseUrl/weather?lat=$lat&lon=$lon&appid=$apiKey&units=metric'))
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Weather data request timed out. Please check your internet connection.'),
          );

      if (currentWeatherResponse.statusCode != 200) {
        throw Exception('Unable to fetch weather data. Please try again later.');
      }

      final forecastResponse = await client
          .get(Uri.parse('$baseUrl/forecast?lat=$lat&lon=$lon&appid=$apiKey&units=metric'))
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Forecast data request timed out. Please check your internet connection.'),
          );

      if (forecastResponse.statusCode != 200) {
        throw Exception('Unable to fetch forecast data. Please try again later.');
      }

      currentWeather = json.decode(currentWeatherResponse.body);
      var forecastData = json.decode(forecastResponse.body);
      forecast = forecastData['list'];
      error = null;
    } catch (e) {
      if (e.toString().contains('SocketException')) {
        throw Exception('No internet connection. Please check your network settings.');
      } else if (e.toString().contains('TimeoutException')) {
        throw Exception('Request timed out. Please check your internet connection and try again.');
      } else {
        throw Exception('Error fetching weather data. Please try again.');
      }
    } finally {
      client.close();
    }
  }
} 
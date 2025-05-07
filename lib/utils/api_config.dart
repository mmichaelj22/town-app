import 'package:flutter/services.dart';
import 'dart:io';

class ApiConfig {
  // Singleton pattern
  static final ApiConfig _instance = ApiConfig._internal();
  factory ApiConfig() => _instance;
  ApiConfig._internal();

  // Cache the API key once we've retrieved it
  String? _cachedApiKey;

  // Method channel for communicating with native code
  static const MethodChannel _platform =
      MethodChannel('com.michael.town/config');

  static Future<String> getGoogleApiKey() async {
    // If we've already cached the key, return it
    if (_instance._cachedApiKey != null) {
      return _instance._cachedApiKey!;
    }

    try {
      final String apiKey = await _platform.invokeMethod('getGoogleApiKey');
      // Cache the key for future use
      _instance._cachedApiKey = apiKey;
      print("Successfully retrieved Google API key from native code");
      return apiKey;
    } on PlatformException catch (e) {
      print("Failed to get API key: ${e.message}");

      // In a development environment, you might want to provide a fallback for testing
      if (Platform.isIOS) {
        // Check if this is a debug build
        assert(() {
          print(
              "Debug mode: You may want to add a test API key here for development");
          return true;
        }());
      }

      return "";
    }
  }
}

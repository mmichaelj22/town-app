// In a separate file like lib/utils/api_config.dart
import 'package:flutter/services.dart';

class ApiConfig {
  static Future<String> getGoogleApiKey() async {
    try {
      // This channel name should match the one you set up in AppDelegate.swift
      const platform = MethodChannel('com.michael.town/config');
      final String apiKey = await platform.invokeMethod('getGoogleApiKey');
      return apiKey;
    } on PlatformException catch (e) {
      print("Failed to get API key: ${e.message}");
      return "";
    }
  }
}

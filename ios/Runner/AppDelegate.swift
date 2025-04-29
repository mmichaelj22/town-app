import UIKit
import Flutter
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Set up the Google Maps API key
    if let apiKey = Bundle.main.object(forInfoDictionaryKey: "GoogleMapsAPIKey") as? String {
      // If this works, Config.xcconfig is working
      GMSServices.provideAPIKey(apiKey)
      
      // Set up the method channel for Dart code to request the API key
      let controller = window?.rootViewController as! FlutterViewController
      let methodChannel = FlutterMethodChannel(
        name: "com.michael.town/config",
        binaryMessenger: controller.binaryMessenger)
      
      // Handle method calls from Dart
      methodChannel.setMethodCallHandler { [weak self] (call, result) in
        // Handle the getGoogleApiKey method
        if call.method == "getGoogleApiKey" {
          if let apiKey = Bundle.main.object(forInfoDictionaryKey: "GoogleMapsAPIKey") as? String {
            result(apiKey)
          } else {
            result(FlutterError(code: "UNAVAILABLE",
                               message: "API key not available",
                               details: nil))
          }
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
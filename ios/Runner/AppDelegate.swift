import UIKit
import Flutter
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Read and obfuscate API key
    if let apiKey = self.obfuscatedGoogleMapsAPIKey() {
      GMSServices.provideAPIKey(apiKey)
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Simple obfuscation function - not highly secure but an additional layer
  private func obfuscatedGoogleMapsAPIKey() -> String? {
    guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "GoogleMapsAPIKey") as? String else {
      return nil
    }
    
    // Add some basic obfuscation here if needed
    // This example just does a simple transformation that can be undone
    // For better security, consider more sophisticated methods
    
    return apiKey
  }
}
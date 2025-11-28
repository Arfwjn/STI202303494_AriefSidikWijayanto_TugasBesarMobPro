import Flutter
import UIKit
import GoogleMaps // Tambahkan ini

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Tambahkan baris ini
    GMSServices.provideAPIKey("GANTI_DENGAN_GOOGLE_MAPS_API_KEY_ANDA") 

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
import Flutter
import UIKit
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // iOS background task se MORA registrovati pre nego što launch završi.
    // Identifikator mora da se poklapa sa BackgroundRefetch.taskName (Dart) i sa
    // BGTaskSchedulerPermittedIdentifiers (Info.plist). Frekvencija je u sekundama
    // i tretira se kao najraniji termin — sistem odlučuje kada zaista pokreće task.
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "troskovnik.refetch.pending",
      frequency: NSNumber(value: 3600)
    )
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}

import UIKit
import Flutter
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // here, Without this code the task will not work.
    SwiftFlutterForegroundTaskPlugin.setPluginRegistrantCallback(registerPlugins)
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }


    let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
    let methodChannel = FlutterMethodChannel(name: "com.example.vitaltrack_sample_app/keepAlive", binaryMessenger: controller.binaryMessenger)

    methodChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      if (call.method == "keepAlive") {
        self.keepAlive()
        result("Keep Alive called on iOS")
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    
    UNUserNotificationCenter.current().delegate = self

    
    

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

    private func keepAlive() {
    // 백그라운드 작업을 처리하는 로직 추가
    scheduleLocalNotification()
  }

    private func scheduleLocalNotification() {
    let content = UNMutableNotificationContent()
    content.title = "VitalTrack is running in background"
    content.body = "VitalTrack이 데이터를 수집중입니다."
    content.sound = .default

    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
    let request = UNNotificationRequest(identifier: "keepAliveNotification", content: content, trigger: trigger)

    UNUserNotificationCenter.current().add(request, withCompletionHandler: { (error) in
      if let error = error {
        print("Error adding notification: \(error.localizedDescription)")
      }
    })
  }
}

// here
func registerPlugins(registry: FlutterPluginRegistry) {
  GeneratedPluginRegistrant.register(with: registry)
}


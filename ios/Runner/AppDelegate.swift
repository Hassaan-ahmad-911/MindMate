import Flutter
import UIKit
import UserNotifications
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Gentle reminders: lets the plugin work when a reminder is tapped while
    // the app is closed, and shows reminders while the app is open.
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate

    GeneratedPluginRegistrant.register(with: self)

    // Opens the phone's own share sheet with a short text (used by the
    // check-ins' "Reach out to someone you trust"). The user picks the app
    // and the person; MindMate sends nothing itself.
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "mindmate/share",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { call, result in
        guard call.method == "shareText" else {
          result(FlutterMethodNotImplemented)
          return
        }
        let args = call.arguments as? [String: Any]
        let text = args?["text"] as? String ?? ""
        let sheet = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let popover = sheet.popoverPresentationController {
          popover.sourceView = controller.view
          popover.sourceRect = CGRect(
            x: controller.view.bounds.midX, y: controller.view.bounds.midY,
            width: 0, height: 0)
          popover.permittedArrowDirections = []
        }
        controller.present(sheet, animated: true)
        result(true)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

import UIKit
import Flutter
import SystemConfiguration.CaptiveNetwork

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        let controller = window?.rootViewController as! FlutterViewController
        let macChannel = FlutterMethodChannel(name: "mac_address_channel", binaryMessenger: controller.binaryMessenger)

        macChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
            if call.method == "getMacAddress" {
                result(self.getMacAddress())
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func getMacAddress() -> String? {
        if let interfaces = CNCopySupportedInterfaces() as NSArray? {
            for interface in interfaces {
                if let interfaceInfo = CNCopyCurrentNetworkInfo(interface as! CFString) as NSDictionary? {
                    return interfaceInfo[kCNNetworkInfoKeyBSSID as String] as? String
                }
            }
        }
        return nil
    }
}
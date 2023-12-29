import Flutter
import UIKit

public class GoogleMediapipePoseDetectionPlugin: NSObject, FlutterPlugin {
    
  public static func register(with registrar: FlutterPluginRegistrar) {
      PoseDetector.register(with: registrar)
  }
}

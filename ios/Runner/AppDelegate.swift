import Flutter
import UIKit
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let visionOcrChannel = "com.mycompany.balanzo/vision_ocr"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: AppDelegate.visionOcrChannel,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "recognizeText":
        guard let args = call.arguments as? [String: Any],
              let path = args["path"] as? String else {
          result(FlutterError(code: "bad_args", message: "Missing path", details: nil))
          return
        }
        DispatchQueue.global(qos: .userInitiated).async {
          let text = Self.recognizeText(at: path)
          DispatchQueue.main.async {
            if let text = text, !text.isEmpty {
              result(text)
            } else {
              result(FlutterError(code: "ocr_failed", message: "Vision OCR returned no text", details: nil))
            }
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Apple Vision OCR — matches macOS Vision used in dev fixtures; more accurate
  /// than ML Kit on dense e-kassa receipt JPEGs.
  private static func recognizeText(at path: String) -> String? {
    guard let image = UIImage(contentsOfFile: path),
          let cgImage = image.cgImage else {
      return nil
    }

    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = false
    if #available(iOS 16.0, *) {
      request.automaticallyDetectsLanguage = true
    }
    request.recognitionLanguages = ["en-US", "az-AZ"]

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    do {
      try handler.perform([request])
    } catch {
      return nil
    }

    var lines: [(CGFloat, String)] = []
    for observation in request.results ?? [] {
      guard let candidate = observation.topCandidates(1).first else { continue }
      lines.append((observation.boundingBox.origin.y, candidate.string))
    }
    lines.sort { $0.0 > $1.0 }
    return lines.map { $0.1 }.joined(separator: "\n")
  }
}

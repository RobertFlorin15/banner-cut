import Flutter
import PhotosUI
import UIKit
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, PHPickerViewControllerDelegate {
  private var pendingPhoto: FlutterResult?

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "app.bannercut/photo",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "pickPhoto" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let self else {
        result(nil)
        return
      }
      self.pickPhoto(result)
    }
  }

  private func pickPhoto(_ result: @escaping FlutterResult) {
    guard pendingPhoto == nil else {
      result(FlutterError(code: "BUSY", message: "A picker is already open.", details: nil))
      return
    }
    let window = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first(where: \.isKeyWindow)
    guard let presenter = window?.rootViewController else {
      result(FlutterError(code: "PICKER", message: "No active window.", details: nil))
      return
    }
    var configuration = PHPickerConfiguration()
    configuration.filter = .images
    configuration.selectionLimit = 1
    configuration.preferredAssetRepresentationMode = .compatible
    let picker = PHPickerViewController(configuration: configuration)
    picker.delegate = self
    pendingPhoto = result
    presenter.present(picker, animated: true)
  }

  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true)
    guard let result = pendingPhoto else { return }
    guard let item = results.first?.itemProvider else {
      pendingPhoto = nil
      result(nil)
      return
    }
    item.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] url, _ in
      let data: Data?
      if let url, let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
         size <= 20 * 1024 * 1024 {
        data = try? Data(contentsOf: url)
      } else {
        data = nil
      }
      DispatchQueue.main.async {
        self?.pendingPhoto = nil
        if let data {
          result(FlutterStandardTypedData(bytes: data))
        } else {
          result(FlutterError(code: "PHOTO", message: "Photo cannot be read.", details: nil))
        }
      }
    }
  }
}

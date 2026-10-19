import AVFoundation
import Foundation
import UIKit
import Vision
import VisionKit

// MARK: - Scanner Function Namespace

/// Scanner bridge functions.
/// Namespace: "WuninsuScanner.*"
enum WuninsuScannerFunctions {

    // MARK: - WuninsuScanner.Scan

    /// Parameters: id, event, prompt, formats
    /// Returns: {started: true}. The outcome is dispatched later to `event` as {value, format, id, error}.
    class Scan: BridgeFunction {
        func execute(parameters: [String: Any]) throws -> [String: Any] {
            guard let event = parameters["event"] as? String else {
                return BridgeResponse.error(code: "INVALID_PARAMETERS", message: "event is required")
            }

            let id = parameters["id"] as? String
            let prompt = parameters["prompt"] as? String
            let formats = (parameters["formats"] as? [String]) ?? ["qr"]

            DispatchQueue.main.async {
                WuninsuScannerSession.start(event: event, id: id, prompt: prompt, formats: formats)
            }

            return BridgeResponse.success(data: ["started": true])
        }
    }

    static func send(_ event: String, id: String?, value: String?, format: String?, error: String?) {
        var payload: [String: Any] = [:]
        payload["value"] = value
        payload["format"] = format
        payload["id"] = id
        payload["error"] = error

        DispatchQueue.main.async {
            LaravelBridge.shared.send?(event, payload)
        }
    }
}

// MARK: - Scanner screen

/// One open scanner: a VisionKit DataScannerViewController in a navigation controller with a Cancel button.
final class WuninsuScannerSession: NSObject, DataScannerViewControllerDelegate, UIAdaptivePresentationControllerDelegate {

    /// Keeps the open session (and its delegate) alive.
    private static var current: WuninsuScannerSession?

    private let event: String
    private let id: String?
    private var finished = false
    private weak var container: UIViewController?

    private init(event: String, id: String?) {
        self.event = event
        self.id = id
    }

    static func start(event: String, id: String?, prompt: String?, formats: [String]) {
        guard current == nil else {
            WuninsuScannerFunctions.send(event, id: id, value: nil, format: nil, error: "failed")
            return
        }

        guard DataScannerViewController.isSupported else {
            WuninsuScannerFunctions.send(event, id: id, value: nil, format: nil, error: "unavailable")
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            present(event: event, id: id, prompt: prompt, formats: formats)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    granted
                        ? present(event: event, id: id, prompt: prompt, formats: formats)
                        : WuninsuScannerFunctions.send(event, id: id, value: nil, format: nil, error: "permission_denied")
                }
            }
        default:
            WuninsuScannerFunctions.send(event, id: id, value: nil, format: nil, error: "permission_denied")
        }
    }

    private static func present(event: String, id: String?, prompt: String?, formats: [String]) {
        guard DataScannerViewController.isAvailable, let presenter = topViewController() else {
            WuninsuScannerFunctions.send(event, id: id, value: nil, format: nil, error: "unavailable")
            return
        }

        let session = WuninsuScannerSession(event: event, id: id)
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: symbologies(formats))],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = session
        scanner.title = prompt ?? "Scan code"
        scanner.navigationItem.leftBarButtonItem = UIBarButtonItem(
            systemItem: .cancel,
            primaryAction: UIAction { _ in session.finish(value: nil, format: nil, error: "cancelled") }
        )

        let container = UINavigationController(rootViewController: scanner)
        container.presentationController?.delegate = session
        session.container = container
        current = session

        presenter.present(container, animated: true) {
            do {
                try scanner.startScanning()
            } catch {
                session.finish(value: nil, format: nil, error: "unavailable")
            }
        }
    }

    // MARK: DataScannerViewControllerDelegate

    func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
        for item in addedItems {
            if case let .barcode(barcode) = item, let value = barcode.payloadStringValue {
                finish(value: value, format: Self.formatName(barcode.observation.symbology), error: nil)
                return
            }
        }
    }

    func dataScanner(_ dataScanner: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) {
        finish(value: nil, format: nil, error: "unavailable")
    }

    // MARK: UIAdaptivePresentationControllerDelegate

    /// Swiped down.
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        finish(value: nil, format: nil, error: "cancelled", dismiss: false)
    }

    private func finish(value: String?, format: String?, error: String?, dismiss: Bool = true) {
        guard !finished else { return }
        finished = true

        if let scanner = (container as? UINavigationController)?.viewControllers.first as? DataScannerViewController {
            scanner.stopScanning()
        }

        let send = { [event, id] in
            WuninsuScannerFunctions.send(event, id: id, value: value, format: format, error: error)
        }

        if dismiss, let container = container {
            container.dismiss(animated: true, completion: send)
        } else {
            send()
        }

        Self.current = nil
    }

    // MARK: Helpers

    private static func topViewController() -> UIViewController? {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }

        var top = window?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }

        return top
    }

    private static let symbologyNames: [String: VNBarcodeSymbology] = [
        "qr": .qr,
        "ean13": .ean13,
        "ean8": .ean8,
        "upca": .ean13, // UPC-A is read as EAN-13 by Vision
        "upce": .upce,
        "code128": .code128,
        "code39": .code39,
        "code93": .code93,
        "codabar": .codabar,
        "itf": .itf14,
        "pdf417": .pdf417,
        "aztec": .aztec,
        "datamatrix": .dataMatrix,
    ]

    private static func symbologies(_ formats: [String]) -> [VNBarcodeSymbology] {
        let mapped = formats.compactMap { symbologyNames[$0] }
        return mapped.isEmpty ? [.qr] : Array(Set(mapped))
    }

    private static func formatName(_ symbology: VNBarcodeSymbology) -> String {
        symbologyNames.first { $0.key != "upca" && $0.value == symbology }?.key ?? "unknown"
    }
}

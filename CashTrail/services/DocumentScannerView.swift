import SwiftUI
import VisionKit
import UIKit

/// Wraps VNDocumentCameraViewController so it can be used from SwiftUI.
/// This gives a proper "scan a document" camera flow with edge detection
/// and cropping, which produces much cleaner images for OCR than a plain photo.
struct DocumentScannerView: UIViewControllerRepresentable {
    var onScanComplete: (UIImage) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScannerView

        init(_ parent: DocumentScannerView) {
            self.parent = parent
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            // Note: no controller.dismiss() here. This scanner is embedded directly
            // as SwiftUI content (not presented modally on top of another VC), so
            // calling dismiss(animated:) would bubble up and dismiss the enclosing
            // sheet instead. The parent view handles the transition by switching
            // its `stage` state once it receives this callback.
            guard scan.pageCount > 0 else {
                parent.onCancel()
                return
            }
            // Only the first page is used — receipts are almost always single-page.
            let image = scan.imageOfPage(at: 0)
            parent.onScanComplete(image)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.onCancel()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            parent.onCancel()
        }
    }
}


import AppKit
import Foundation
import ScreenCaptureKit

struct CaptureProcessingResult {
    let previewData: Data?
    let safeSummary: String
    let skippedReason: String?
    let redactionReasons: [String]
}

struct CapturedFrame {
    let cgImage: CGImage
    let capturedDisplayName: String
}

actor CaptureCoordinator {
    private let screenCaptureService = ScreenCaptureService()
    private let ocrRedactor = OCRRedactor()

    private var lastCaptureFingerprint: String?
    private var lastCaptureDate: Date?

    func process(
        metadata: WindowMetadata,
        privacyDecision: PrivacyDecision,
        alignment: Alignment,
        settings: AppSettings,
        permissionSnapshot: PermissionSnapshot
    ) async -> CaptureProcessingResult {
        if privacyDecision.policy == .noCapture {
            return CaptureProcessingResult(
                previewData: nil,
                safeSummary: "Sensitive context blocked before any screenshot was captured.",
                skippedReason: privacyDecision.reason,
                redactionReasons: []
            )
        }

        if privacyDecision.policy == .metadataOnly {
            return CaptureProcessingResult(
                previewData: nil,
                safeSummary: "User is in \(metadata.activeAppName). Content was not visually captured.",
                skippedReason: nil,
                redactionReasons: []
            )
        }

        guard permissionSnapshot.screenRecordingGranted else {
            return CaptureProcessingResult(
                previewData: nil,
                safeSummary: "Visual capture skipped because Screen Recording permission is missing.",
                skippedReason: "Missing Screen Recording permission",
                redactionReasons: []
            )
        }

        let fingerprint = [metadata.activeAppName, metadata.windowTitle ?? ""].joined(separator: "::")
        let shouldCapture = shouldCaptureVisualContext(fingerprint: fingerprint, now: Date(), settings: settings)
        if !shouldCapture {
            return CaptureProcessingResult(
                previewData: nil,
                safeSummary: "Visual capture unchanged recently. Using metadata summary for this context item.",
                skippedReason: "Capture throttled because context has not changed",
                redactionReasons: []
            )
        }

        do {
            let capturedFrame = try await screenCaptureService.captureActiveWindow(metadata: metadata)

            if privacyDecision.policy == .normalScreenshot {
                lastCaptureFingerprint = fingerprint
                lastCaptureDate = Date()
                let previewData = NSBitmapImageRep(cgImage: capturedFrame.cgImage).representation(using: .jpeg, properties: [.compressionFactor: 0.9])

                return CaptureProcessingResult(
                    previewData: previewData,
                    safeSummary: "User is in \(metadata.activeAppName). Low-risk screenshot captured.",
                    skippedReason: nil,
                    redactionReasons: []
                )
            }

            let redactionResult = try await ocrRedactor.redact(cgImage: capturedFrame.cgImage, metadata: metadata, decision: privacyDecision)
            lastCaptureFingerprint = fingerprint
            lastCaptureDate = Date()

            return CaptureProcessingResult(
                previewData: redactionResult.redactedPreviewData,
                safeSummary: redactionResult.safeSummary,
                skippedReason: redactionResult.discardedReason,
                redactionReasons: redactionResult.redactionReasons
            )
        } catch {
            Logger.log("Capture", "Capture failed: \(error.localizedDescription)")
            return CaptureProcessingResult(
                previewData: nil,
                safeSummary: "Capture failed. Metadata-only summary stored for this context item.",
                skippedReason: error.localizedDescription,
                redactionReasons: []
            )
        }
    }

    private func shouldCaptureVisualContext(fingerprint: String, now: Date, settings: AppSettings) -> Bool {
        guard let lastCaptureDate, let lastCaptureFingerprint else {
            return true
        }

        if lastCaptureFingerprint != fingerprint {
            return true
        }

        return now.timeIntervalSince(lastCaptureDate) >= TimeInterval(settings.screenshotIntervalSeconds)
    }
}

private struct ScreenCaptureService: Sendable {
    nonisolated init() {}

    nonisolated func captureActiveWindow(metadata: WindowMetadata) async throws -> CapturedFrame {
        let shareableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard !shareableContent.displays.isEmpty else {
            throw NSError(domain: "ScreenCaptureService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No displays available for capture"])
        }

        let targetDisplay = selectTargetDisplay(from: shareableContent.displays, metadata: metadata) ?? shareableContent.displays[0]
        let ownBundleIdentifier = Bundle.main.bundleIdentifier
        let ownWindows = shareableContent.windows.filter { $0.owningApplication?.bundleIdentifier == ownBundleIdentifier }

        let filter = SCContentFilter(display: targetDisplay, excludingWindows: ownWindows)
        let configuration = SCStreamConfiguration()
        configuration.width = max(1280, Int(targetDisplay.width))
        configuration.height = max(900, Int(targetDisplay.height))

        let displayImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        let croppedImage = cropWindowImage(from: displayImage, displayFrame: targetDisplay.frame, metadata: metadata) ?? displayImage

        return CapturedFrame(cgImage: croppedImage, capturedDisplayName: "Display \(targetDisplay.displayID)")
    }

    nonisolated private func selectTargetDisplay(from displays: [SCDisplay], metadata: WindowMetadata) -> SCDisplay? {
        guard let bounds = metadata.windowBounds else { return nil }
        let centerPoint = CGPoint(x: bounds.midX, y: bounds.midY)
        return displays.first { $0.frame.contains(centerPoint) }
    }

    nonisolated private func cropWindowImage(from displayImage: CGImage, displayFrame: CGRect, metadata: WindowMetadata) -> CGImage? {
        guard let windowBounds = metadata.windowBounds else { return nil }

        let scaleX = CGFloat(displayImage.width) / max(displayFrame.width, 1)
        let scaleY = CGFloat(displayImage.height) / max(displayFrame.height, 1)

        let cropRect = CGRect(
            x: (windowBounds.minX - displayFrame.minX) * scaleX,
            y: (windowBounds.minY - displayFrame.minY) * scaleY,
            width: windowBounds.width * scaleX,
            height: windowBounds.height * scaleY
        ).integral

        let clampedCropRect = cropRect.intersection(CGRect(x: 0, y: 0, width: CGFloat(displayImage.width), height: CGFloat(displayImage.height)))
        guard clampedCropRect.width > 0, clampedCropRect.height > 0 else { return nil }
        return displayImage.cropping(to: clampedCropRect)
    }
}

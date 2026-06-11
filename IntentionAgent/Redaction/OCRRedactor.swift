import AppKit
import Foundation
import Vision

struct RedactionResult {
    let redactedPreviewData: Data?
    let safeSummary: String
    let redactionReasons: [String]
    let discardedReason: String?
}

struct OCRRedactor: Sendable {
    nonisolated init() {}

    private let detectionPatterns: [(reason: String, expression: NSRegularExpression)] = [
        ("email pattern redacted", try! NSRegularExpression(pattern: "[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}", options: [.caseInsensitive])),
        ("phone number redacted", try! NSRegularExpression(pattern: "\\b(?:\\+?\\d{1,3}[ -]?)?(?:\\d[ -]?){10,12}\\b", options: [])),
        ("UPI identifier redacted", try! NSRegularExpression(pattern: "\\b[a-zA-Z0-9._-]+@[a-zA-Z]+\\b", options: [])),
        ("OTP code redacted", try! NSRegularExpression(pattern: "\\b(?:otp|code)[: ]{0,3}\\d{4,8}\\b", options: [.caseInsensitive])),
        ("credit card pattern redacted", try! NSRegularExpression(pattern: "\\b(?:\\d[ -]?){13,19}\\b", options: [])),
        ("JWT-like token redacted", try! NSRegularExpression(pattern: "eyJ[a-zA-Z0-9_-]{10,}\\.[a-zA-Z0-9_-]{10,}\\.[a-zA-Z0-9_-]{10,}", options: [])),
        ("environment variable pattern redacted", try! NSRegularExpression(pattern: "\\b[A-Z0-9_]{3,}=.+", options: [])),
        ("API key pattern redacted", try! NSRegularExpression(pattern: "\\b(?:sk-|AKIA|ghp_)[A-Za-z0-9_-]{8,}\\b", options: []))
    ]

    private let hardSensitiveKeywords = [
        "cvv", "otp", "card number", "secret_key", "private_key", "password", "database_url", "openai_api_key", "aws_secret_access_key"
    ]

    nonisolated func redact(cgImage: CGImage, metadata: WindowMetadata, decision: PrivacyDecision) async throws -> RedactionResult {
        let recognizedRegions = try await recognizeTextRegions(in: cgImage)
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)

        var redactionRects: [CGRect] = []
        var redactionReasons: [String] = []
        var combinedRecognizedText = ""

        for region in recognizedRegions {
            combinedRecognizedText += region.text.lowercased() + "\n"

            for detectionPattern in detectionPatterns {
                let range = NSRange(region.text.startIndex..<region.text.endIndex, in: region.text)
                if detectionPattern.expression.firstMatch(in: region.text, options: [], range: range) != nil {
                    redactionRects.append(region.boundingRect)
                    redactionReasons.append(detectionPattern.reason)
                }
            }
        }

        if hardSensitiveKeywords.contains(where: { combinedRecognizedText.contains($0) }) {
            return RedactionResult(
                redactedPreviewData: nil,
                safeSummary: sensitiveSummary(for: metadata, decision: decision),
                redactionReasons: redactionReasons,
                discardedReason: "Screenshot discarded due to sensitive text."
            )
        }

        redactionRects.append(contentsOf: additionalPolicyRedactionRects(for: metadata, imageSize: imageSize))

        let redactedImage = renderMaskedImage(from: cgImage, imageSize: imageSize, redactionRects: redactionRects)
        let previewData = jpegData(for: redactedImage)

        return RedactionResult(
            redactedPreviewData: previewData,
            safeSummary: safeSummary(for: metadata, decision: decision),
            redactionReasons: Array(Set(redactionReasons)).sorted(),
            discardedReason: nil
        )
    }

    nonisolated private func recognizeTextRegions(in cgImage: CGImage) async throws -> [RecognizedRegion] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        let observations = request.results ?? []
        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)

        return observations.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let boundingBox = observation.boundingBox
            let imageRect = CGRect(
                x: boundingBox.minX * imageWidth,
                y: (1 - boundingBox.maxY) * imageHeight,
                width: boundingBox.width * imageWidth,
                height: boundingBox.height * imageHeight
            ).integral.insetBy(dx: -4, dy: -4)

            return RecognizedRegion(text: candidate.string, boundingRect: imageRect)
        }
    }

    nonisolated private func additionalPolicyRedactionRects(for metadata: WindowMetadata, imageSize: CGSize) -> [CGRect] {
        let appName = metadata.activeAppName.lowercased()
        let title = metadata.windowTitle?.lowercased() ?? ""
        var rects: [CGRect] = []

        if appName.contains("youtube") || title.contains("youtube") {
            rects.append(CGRect(x: imageSize.width * 0.74, y: 0, width: imageSize.width * 0.26, height: imageSize.height))
            rects.append(CGRect(x: 0, y: imageSize.height * 0.82, width: imageSize.width, height: imageSize.height * 0.18))
        }

        if appName.contains("instagram") || title.contains("instagram") {
            rects.append(CGRect(x: imageSize.width * 0.7, y: 0, width: imageSize.width * 0.3, height: imageSize.height))
            rects.append(CGRect(x: 0, y: imageSize.height * 0.85, width: imageSize.width, height: imageSize.height * 0.15))
        }

        return rects
    }

    nonisolated private func renderMaskedImage(from cgImage: CGImage, imageSize: CGSize, redactionRects: [CGRect]) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        let context = CGContext(
            data: nil,
            width: Int(imageSize.width),
            height: Int(imageSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        )!

        context.draw(cgImage, in: CGRect(origin: .zero, size: imageSize))

        context.setFillColor(NSColor.black.withAlphaComponent(0.88).cgColor)
        for rect in redactionRects {
            context.fill(rect.integral)
        }

        return context.makeImage() ?? cgImage
    }

    nonisolated private func jpegData(for cgImage: CGImage) -> Data? {
        NSBitmapImageRep(cgImage: cgImage).representation(using: .jpeg, properties: [.compressionFactor: 0.85])
    }

    nonisolated private func safeSummary(for metadata: WindowMetadata, decision: PrivacyDecision) -> String {
        let contextLabel = browserContextLabel(for: metadata)

        switch decision.policy {
        case .metadataOnly:
            if let contextLabel, !contextLabel.isEmpty {
                return "User is in \(metadata.activeAppName) on \"\(contextLabel)\". Content was not visually captured."
            }
            return "User is in \(metadata.activeAppName). Content was not visually captured."
        case .noCapture:
            return sensitiveSummary(for: metadata, decision: decision)
        case .redactedScreenshot, .normalScreenshot:
            if let contextLabel, !contextLabel.isEmpty {
                return "User is in \(metadata.activeAppName) on \"\(contextLabel)\". Visual context was reviewed with redaction applied."
            }
            return "User is in \(metadata.activeAppName). Visual context was reviewed with redaction applied."
        }
    }

    nonisolated private func sensitiveSummary(for metadata: WindowMetadata, decision: PrivacyDecision) -> String {
        "Sensitive \(decision.category.rawValue) context in \(metadata.activeAppName). Visual capture blocked."
    }

    nonisolated private func browserContextLabel(for metadata: WindowMetadata) -> String? {
        guard let windowTitle = metadata.windowTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !windowTitle.isEmpty else {
            return nil
        }

        let appName = metadata.activeAppName.lowercased()
        if appName.contains("chrome") || appName.contains("safari") || appName.contains("arc") || appName.contains("firefox") {
            return windowTitle
        }

        return windowTitle
    }
}

private struct RecognizedRegion {
    let text: String
    let boundingRect: CGRect
}

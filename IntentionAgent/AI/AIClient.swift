import AppKit
import Foundation

struct AIClient {
    private struct ChatCompletionResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let content: String?
            }

            let message: Message
        }

        let choices: [Choice]
    }

    func review(
        payload: FiveMinuteAIPayload,
        records: [CaptureRecord],
        libraryStore: CaptureLibraryStore,
        settings: AppSettings
    ) async throws -> AIReviewResponse {
        guard !settings.umansAPIKey.isEmpty else {
            throw NSError(domain: "AIClient", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing Umans API key"])
        }

        let url = URL(string: settings.umansBaseURLString)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(settings.umansAPIKey)", forHTTPHeaderField: "Authorization")

        let payloadJSONData = try JSONEncoder().encode(payload)
        let payloadJSONString = String(data: payloadJSONData, encoding: .utf8) ?? "{}"

        var contentBlocks: [[String: Any]] = [
            [
                "type": "text",
                "text": "You are an intention alignment reviewer. Read the following five-minute safe context payload and respond with strict JSON matching this shape: {\"alignment\":\"aligned|drift|neutral|unknown|sensitive\",\"message\":\"...\",\"suggested_action\":\"return|allow_5_min|switch_intention|pause|continue\"}. Only return JSON. Payload: \(payloadJSONString)"
            ]
        ]

        if settings.sendRedactedImagesToAI {
            for record in records where record.redactedPreviewPath != nil {
                guard let image = libraryStore.previewImage(for: record),
                      let imageData = image.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: imageData),
                      let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
                    continue
                }

                let base64String = jpegData.base64EncodedString()
                let dataURI = "data:image/jpeg;base64,\(base64String)"
                contentBlocks.append([
                    "type": "text",
                    "text": "Redacted screenshot for \(record.activeAppName) at \(record.timestamp.captureTimeText). Context: \(record.windowTitle ?? "Unknown page")."
                ])
                contentBlocks.append([
                    "type": "image_url",
                    "image_url": ["url": dataURI]
                ])
            }
        }

        let requestBody: [String: Any] = [
            "model": settings.umansModelName,
            "stream": false,
            "messages": [
                [
                    "role": "system",
                    "content": "You judge whether the user stayed within their intention. You never assume hidden content from metadata-only apps and you should treat skipped sensitive contexts as non-visual evidence only."
                ],
                [
                    "role": "user",
                    "content": contentBlocks
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let configuration = URLSessionConfiguration.default
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        let session = URLSession(configuration: configuration)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error body"
            throw NSError(domain: "AIClient", code: 2, userInfo: [NSLocalizedDescriptionKey: "AI review failed: \(errorBody)"])
        }

        let decodedResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        let rawContent = decodedResponse.choices.first?.message.content ?? "{}"
        let jsonSubstring = extractJSONObject(from: rawContent) ?? rawContent
        let responseData = Data(jsonSubstring.utf8)

        return try JSONDecoder().decode(AIReviewResponse.self, from: responseData)
    }

    private func extractJSONObject(from text: String) -> String? {
        guard let firstBrace = text.firstIndex(of: "{"), let lastBrace = text.lastIndex(of: "}") else {
            return nil
        }
        return String(text[firstBrace...lastBrace])
    }
}

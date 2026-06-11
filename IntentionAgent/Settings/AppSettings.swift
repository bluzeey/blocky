import Foundation

struct AppSettings: Codable, Equatable {
    var umansAPIKey: String
    var umansBaseURLString: String
    var umansModelName: String
    var metadataPollIntervalSeconds: Int
    var screenshotIntervalSeconds: Int
    var aiReviewIntervalSeconds: Int
    var retentionHours: Int
    var storeRedactedPreviews: Bool
    var sendRedactedImagesToAI: Bool
    var strictModeEnabled: Bool
    var allowedNormalScreenshotApps: [String]
    var userBlockedAppKeywords: [String]
    var userSensitiveTitleKeywords: [String]

    static let `default` = AppSettings(
        umansAPIKey: "",
        umansBaseURLString: "https://api.code.umans.ai/v1/chat/completions",
        umansModelName: "umans-coder",
        metadataPollIntervalSeconds: 10,
        screenshotIntervalSeconds: 45,
        aiReviewIntervalSeconds: 300,
        retentionHours: 24,
        storeRedactedPreviews: true,
        sendRedactedImagesToAI: true,
        strictModeEnabled: true,
        allowedNormalScreenshotApps: [],
        userBlockedAppKeywords: [],
        userSensitiveTitleKeywords: []
    )
}

import Foundation

enum AIProviderPreset: String, Codable, CaseIterable, Identifiable {
    case umans
    case openAI = "openai"
    case openRouter = "openrouter"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .umans:
            return "Umans"
        case .openAI:
            return "OpenAI"
        case .openRouter:
            return "OpenRouter"
        }
    }

    var defaultBaseURLString: String {
        switch self {
        case .umans:
            return "https://api.code.umans.ai/v1/chat/completions"
        case .openAI:
            return "https://api.openai.com/v1/chat/completions"
        case .openRouter:
            return "https://openrouter.ai/api/v1/chat/completions"
        }
    }

    var defaultModelName: String {
        switch self {
        case .umans:
            return "umans-coder"
        case .openAI:
            return "gpt-4.1-mini"
        case .openRouter:
            return "openai/gpt-4.1-mini"
        }
    }
}

struct AppSettings: Codable, Equatable {
    var aiProvider: AIProviderPreset
    var aiAPIKey: String
    var aiBaseURLString: String
    var aiModelName: String
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
    var launchAtLoginEnabled: Bool

    var hasAIConfiguration: Bool {
        !aiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static let `default` = AppSettings(
        aiProvider: .umans,
        aiAPIKey: "",
        aiBaseURLString: AIProviderPreset.umans.defaultBaseURLString,
        aiModelName: AIProviderPreset.umans.defaultModelName,
        metadataPollIntervalSeconds: 10,
        screenshotIntervalSeconds: 45,
        aiReviewIntervalSeconds: 120,
        retentionHours: 24,
        storeRedactedPreviews: true,
        sendRedactedImagesToAI: true,
        strictModeEnabled: true,
        allowedNormalScreenshotApps: [],
        userBlockedAppKeywords: [],
        userSensitiveTitleKeywords: [],
        launchAtLoginEnabled: false
    )

    private enum CodingKeys: String, CodingKey {
        case aiProvider
        case aiAPIKey
        case aiBaseURLString
        case aiModelName
        case metadataPollIntervalSeconds
        case screenshotIntervalSeconds
        case aiReviewIntervalSeconds
        case retentionHours
        case storeRedactedPreviews
        case sendRedactedImagesToAI
        case strictModeEnabled
        case allowedNormalScreenshotApps
        case userBlockedAppKeywords
        case userSensitiveTitleKeywords
        case launchAtLoginEnabled
        case umansAPIKey
        case umansBaseURLString
        case umansModelName
    }

    init(
        aiProvider: AIProviderPreset,
        aiAPIKey: String,
        aiBaseURLString: String,
        aiModelName: String,
        metadataPollIntervalSeconds: Int,
        screenshotIntervalSeconds: Int,
        aiReviewIntervalSeconds: Int,
        retentionHours: Int,
        storeRedactedPreviews: Bool,
        sendRedactedImagesToAI: Bool,
        strictModeEnabled: Bool,
        allowedNormalScreenshotApps: [String],
        userBlockedAppKeywords: [String],
        userSensitiveTitleKeywords: [String],
        launchAtLoginEnabled: Bool
    ) {
        self.aiProvider = aiProvider
        self.aiAPIKey = aiAPIKey
        self.aiBaseURLString = aiBaseURLString
        self.aiModelName = aiModelName
        self.metadataPollIntervalSeconds = metadataPollIntervalSeconds
        self.screenshotIntervalSeconds = screenshotIntervalSeconds
        self.aiReviewIntervalSeconds = aiReviewIntervalSeconds
        self.retentionHours = retentionHours
        self.storeRedactedPreviews = storeRedactedPreviews
        self.sendRedactedImagesToAI = sendRedactedImagesToAI
        self.strictModeEnabled = strictModeEnabled
        self.allowedNormalScreenshotApps = allowedNormalScreenshotApps
        self.userBlockedAppKeywords = userBlockedAppKeywords
        self.userSensitiveTitleKeywords = userSensitiveTitleKeywords
        self.launchAtLoginEnabled = launchAtLoginEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings.default

        aiProvider = try container.decodeIfPresent(AIProviderPreset.self, forKey: .aiProvider) ?? defaults.aiProvider
        aiAPIKey = try container.decodeIfPresent(String.self, forKey: .aiAPIKey)
            ?? container.decodeIfPresent(String.self, forKey: .umansAPIKey)
            ?? defaults.aiAPIKey
        aiBaseURLString = try container.decodeIfPresent(String.self, forKey: .aiBaseURLString)
            ?? container.decodeIfPresent(String.self, forKey: .umansBaseURLString)
            ?? defaults.aiBaseURLString
        aiModelName = try container.decodeIfPresent(String.self, forKey: .aiModelName)
            ?? container.decodeIfPresent(String.self, forKey: .umansModelName)
            ?? defaults.aiModelName
        metadataPollIntervalSeconds = try container.decodeIfPresent(Int.self, forKey: .metadataPollIntervalSeconds) ?? defaults.metadataPollIntervalSeconds
        screenshotIntervalSeconds = try container.decodeIfPresent(Int.self, forKey: .screenshotIntervalSeconds) ?? defaults.screenshotIntervalSeconds
        aiReviewIntervalSeconds = try container.decodeIfPresent(Int.self, forKey: .aiReviewIntervalSeconds) ?? defaults.aiReviewIntervalSeconds
        retentionHours = try container.decodeIfPresent(Int.self, forKey: .retentionHours) ?? defaults.retentionHours
        storeRedactedPreviews = try container.decodeIfPresent(Bool.self, forKey: .storeRedactedPreviews) ?? defaults.storeRedactedPreviews
        sendRedactedImagesToAI = try container.decodeIfPresent(Bool.self, forKey: .sendRedactedImagesToAI) ?? defaults.sendRedactedImagesToAI
        strictModeEnabled = try container.decodeIfPresent(Bool.self, forKey: .strictModeEnabled) ?? defaults.strictModeEnabled
        allowedNormalScreenshotApps = try container.decodeIfPresent([String].self, forKey: .allowedNormalScreenshotApps) ?? defaults.allowedNormalScreenshotApps
        userBlockedAppKeywords = try container.decodeIfPresent([String].self, forKey: .userBlockedAppKeywords) ?? defaults.userBlockedAppKeywords
        userSensitiveTitleKeywords = try container.decodeIfPresent([String].self, forKey: .userSensitiveTitleKeywords) ?? defaults.userSensitiveTitleKeywords
        launchAtLoginEnabled = try container.decodeIfPresent(Bool.self, forKey: .launchAtLoginEnabled) ?? defaults.launchAtLoginEnabled
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(aiProvider, forKey: .aiProvider)
        try container.encode(aiAPIKey, forKey: .aiAPIKey)
        try container.encode(aiBaseURLString, forKey: .aiBaseURLString)
        try container.encode(aiModelName, forKey: .aiModelName)
        try container.encode(metadataPollIntervalSeconds, forKey: .metadataPollIntervalSeconds)
        try container.encode(screenshotIntervalSeconds, forKey: .screenshotIntervalSeconds)
        try container.encode(aiReviewIntervalSeconds, forKey: .aiReviewIntervalSeconds)
        try container.encode(retentionHours, forKey: .retentionHours)
        try container.encode(storeRedactedPreviews, forKey: .storeRedactedPreviews)
        try container.encode(sendRedactedImagesToAI, forKey: .sendRedactedImagesToAI)
        try container.encode(strictModeEnabled, forKey: .strictModeEnabled)
        try container.encode(allowedNormalScreenshotApps, forKey: .allowedNormalScreenshotApps)
        try container.encode(userBlockedAppKeywords, forKey: .userBlockedAppKeywords)
        try container.encode(userSensitiveTitleKeywords, forKey: .userSensitiveTitleKeywords)
        try container.encode(launchAtLoginEnabled, forKey: .launchAtLoginEnabled)
    }
}

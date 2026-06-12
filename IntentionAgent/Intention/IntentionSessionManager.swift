import Foundation

private let titleKeywordCategoryMap: [ActivityCategory: Set<String>] = [
    .coding: ["coding", "code", "develop", "debug", "build", "program", "swift", "xcode", "app", "software", "engineer", "deploy", "refactor", "compile", "git", "repo", "terminal", "cli", "script", "api", "backend", "frontend", "fullstack", "ios", "android", "web dev"],
    .productivity: ["write", "writing", "blog", "document", "research", "study", "learn", "read", "paper", "report", "presentation", "slides", "meeting", "plan", "organize", "budget", "spreadsheet", "excel", "notion", "docs"],
    .email: ["email", "inbox", "mail", "compose"],
    .video: ["watch", "stream", "video", "movie", "youtube", "netflix", "show", "episode"],
    .socialMedia: ["social", "twitter", "x", "instagram", "tiktok", "facebook", "reddit", "linkedin", "post", "feed", "scroll", "mastodon", "threads"],
    .messaging: ["chat", "message", "slack", "discord", "text", "whatsapp", "telegram", "communicate"],
    .browsing: ["browse", "surf", "shop", "buy", "news", "read"],
]

private let stopWords: Set<String> = [
    "the", "and", "for", "with", "this", "that", "from", "into", "about",
    "what", "which", "when", "where", "who", "how", "are", "was", "were",
    "been", "have", "has", "had", "will", "would", "could", "should",
    "can", "may", "might", "shall", "does", "did", "not", "but", "just",
    "also", "than", "then", "very", "too", "much", "more", "most", "some",
    "any", "all", "each", "every", "both", "few", "many", "other", "such",
    "only", "own", "same", "here", "there", "being", "because", "over",
    "after", "before", "between", "through", "during", "without", "within",
    "along", "using", "working", "work", "task", "session", "focus",
]

@MainActor
final class IntentionSessionManager {
    func inferCategoriesFromTitle(_ title: String) -> Set<ActivityCategory> {
        let lowercased = title.lowercased()
        var inferred = Set<ActivityCategory>()
        for (category, keywords) in titleKeywordCategoryMap {
            if keywords.contains(where: { lowercased.contains($0) }) {
                inferred.insert(category)
            }
        }
        return inferred
    }

    func significantWords(from title: String) -> Set<String> {
        let words = title.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 && !stopWords.contains($0) }
        return Set(words)
    }

    func remainingTimeText(for session: IntentionSession) -> String {
        let remainingSeconds = max(0, Int(effectiveEndDate(for: session).timeIntervalSinceNow))
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d remaining", minutes, seconds)
    }

    func effectiveEndDate(for session: IntentionSession) -> Date {
        let activePauseSeconds: Int
        if let pauseStartedAt = session.pauseStartedAt {
            activePauseSeconds = Int(Date().timeIntervalSince(pauseStartedAt))
        } else {
            activePauseSeconds = 0
        }

        return session.endsAt.addingTimeInterval(TimeInterval(session.totalPausedSeconds + activePauseSeconds))
    }

    func pause(_ session: IntentionSession) -> IntentionSession {
        guard session.pauseStartedAt == nil else { return session }
        return IntentionSession(
            id: session.id,
            title: session.title,
            startedAt: session.startedAt,
            endsAt: session.endsAt,
            allowedApps: session.allowedApps,
            allowedCategories: session.allowedCategories,
            blockedApps: session.blockedApps,
            blockedCategories: session.blockedCategories,
            aiReviewIntervalSeconds: session.aiReviewIntervalSeconds,
            pauseStartedAt: Date(),
            totalPausedSeconds: session.totalPausedSeconds,
            source: session.source,
            taskId: session.taskId
        )
    }

    func resume(_ session: IntentionSession) -> IntentionSession {
        guard let pauseStartedAt = session.pauseStartedAt else { return session }
        let additionalPausedSeconds = Int(Date().timeIntervalSince(pauseStartedAt))
        return IntentionSession(
            id: session.id,
            title: session.title,
            startedAt: session.startedAt,
            endsAt: session.endsAt,
            allowedApps: session.allowedApps,
            allowedCategories: session.allowedCategories,
            blockedApps: session.blockedApps,
            blockedCategories: session.blockedCategories,
            aiReviewIntervalSeconds: session.aiReviewIntervalSeconds,
            pauseStartedAt: nil,
            totalPausedSeconds: session.totalPausedSeconds + additionalPausedSeconds,
            source: session.source,
            taskId: session.taskId
        )
    }

    func isExpired(_ session: IntentionSession) -> Bool {
        effectiveEndDate(for: session) <= Date()
    }

    func evaluateAlignment(
        session: IntentionSession?,
        metadata: WindowMetadata,
        category: ActivityCategory,
        privacyDecision: PrivacyDecision,
        settings: AppSettings
    ) -> Alignment {
        guard let session else { return .unknown }

        if privacyDecision.isSensitive {
            return .sensitive
        }

        let appName = metadata.activeAppName.lowercased()
        let allowedApps = Set(session.allowedApps.map { $0.lowercased() })
        let blockedApps = Set(session.blockedApps.map { $0.lowercased() } + settings.userBlockedAppKeywords.map { $0.lowercased() })

        if blockedApps.contains(where: { appName.contains($0) }) {
            return .drift
        }

        if session.blockedCategories.contains(category) {
            return .drift
        }

        if allowedApps.contains(where: { appName.contains($0) }) {
            return .aligned
        }

        if session.allowedCategories.contains(category) {
            return .aligned
        }

        if !session.allowedApps.isEmpty || !session.allowedCategories.isEmpty {
            return .neutral
        }

        let titleWords = significantWords(from: session.title)
        if !titleWords.isEmpty {
            let contextText = "\(appName) \(metadata.windowTitle?.lowercased() ?? "")"
            if titleWords.contains(where: { contextText.contains($0) }) {
                return .aligned
            }
        }

        let inferredCategories = inferCategoriesFromTitle(session.title)
        if inferredCategories.isEmpty {
            return .neutral
        }

        if inferredCategories.contains(category) {
            return .aligned
        }

        return .drift
    }
}

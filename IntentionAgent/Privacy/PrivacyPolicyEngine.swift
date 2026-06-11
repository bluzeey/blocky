import Foundation

struct PrivacyDecision: Equatable {
    let policy: CapturePolicy
    let category: ActivityCategory
    let reason: String
    let isSensitive: Bool
}

struct PrivacyPolicyEngine {
    func decidePolicy(for metadata: WindowMetadata, settings: AppSettings) -> PrivacyDecision {
        let bundleIdentifier = metadata.bundleIdentifier?.lowercased() ?? ""
        let title = metadata.windowTitle?.lowercased() ?? ""
        let appName = metadata.activeAppName.lowercased()

        let decision: PrivacyDecision

        if isBrowserApp(bundleIdentifier: bundleIdentifier, appName: appName) {
            if isPrivateWindow(title: title) {
                decision = PrivacyDecision(policy: .noCapture, category: .browsing, reason: "Private or incognito browser window detected", isSensitive: true)
                Logger.log("Privacy", "Decision for \(metadata.activeAppName): \(decision.policy.rawValue) reason=\(decision.reason)")
                return decision
            }

            if isPaymentOrBanking(title: title, appName: appName, settings: settings) {
                decision = PrivacyDecision(policy: .noCapture, category: .payment, reason: "Payment or banking page detected in browser", isSensitive: true)
                Logger.log("Privacy", "Decision for \(metadata.activeAppName): \(decision.policy.rawValue) reason=\(decision.reason)")
                return decision
            }

            if isEmail(title: title, appName: appName) {
                decision = PrivacyDecision(policy: .metadataOnly, category: .email, reason: "Email page in browser is metadata-only", isSensitive: false)
                Logger.log("Privacy", "Decision for \(metadata.activeAppName): \(decision.policy.rawValue) reason=\(decision.reason)")
                return decision
            }

            if isVideo(title: title, appName: appName) {
                decision = PrivacyDecision(policy: .redactedScreenshot, category: .video, reason: "Browser video page stores redacted screenshots", isSensitive: false)
                Logger.log("Privacy", "Decision for \(metadata.activeAppName): \(decision.policy.rawValue) reason=\(decision.reason)")
                return decision
            }

            if isSocial(title: title, appName: appName) {
                decision = PrivacyDecision(policy: .redactedScreenshot, category: .socialMedia, reason: "Browser social page stores redacted screenshots", isSensitive: false)
                Logger.log("Privacy", "Decision for \(metadata.activeAppName): \(decision.policy.rawValue) reason=\(decision.reason)")
                return decision
            }

            let category = classifyBrowserCategory(title: title)
            decision = PrivacyDecision(policy: .redactedScreenshot, category: category, reason: "Browser context stores redacted screenshots by default", isSensitive: false)
            Logger.log("Privacy", "Decision for \(metadata.activeAppName): \(decision.policy.rawValue) reason=\(decision.reason)")
            return decision
        }

        if isPasswordManager(bundleIdentifier: bundleIdentifier, appName: appName) {
            decision = PrivacyDecision(policy: .noCapture, category: .productivity, reason: "Password manager detected", isSensitive: true)
            Logger.log("Privacy", "Decision for \(metadata.activeAppName): \(decision.policy.rawValue) reason=\(decision.reason)")
            return decision
        }

        if isPrivateWindow(title: title) {
            decision = PrivacyDecision(policy: .noCapture, category: .browsing, reason: "Private or incognito window detected", isSensitive: true)
            Logger.log("Privacy", "Decision for \(metadata.activeAppName): \(decision.policy.rawValue) reason=\(decision.reason)")
            return decision
        }

        if isPaymentOrBanking(title: title, appName: appName, settings: settings) {
            decision = PrivacyDecision(policy: .noCapture, category: .payment, reason: "Payment or banking context detected", isSensitive: true)
            Logger.log("Privacy", "Decision for \(metadata.activeAppName): \(decision.policy.rawValue) reason=\(decision.reason)")
            return decision
        }

        if isCodeEditor(bundleIdentifier: bundleIdentifier, appName: appName) {
            decision = PrivacyDecision(policy: .metadataOnly, category: .coding, reason: "Code editor is metadata-only", isSensitive: false)
            Logger.log("Privacy", "Decision for \(metadata.activeAppName): \(decision.policy.rawValue) reason=\(decision.reason)")
            return decision
        }

        if isTerminal(bundleIdentifier: bundleIdentifier, appName: appName) {
            decision = PrivacyDecision(policy: .metadataOnly, category: .coding, reason: "Terminal is metadata-only", isSensitive: false)
            Logger.log("Privacy", "Decision for \(metadata.activeAppName): \(decision.policy.rawValue) reason=\(decision.reason)")
            return decision
        }

        if isEmail(title: title, appName: appName) {
            decision = PrivacyDecision(policy: .metadataOnly, category: .email, reason: "Email context is metadata-only", isSensitive: false)
            Logger.log("Privacy", "Decision for \(metadata.activeAppName): \(decision.policy.rawValue) reason=\(decision.reason)")
            return decision
        }

        if isPrivateMessaging(bundleIdentifier: bundleIdentifier, appName: appName) {
            decision = PrivacyDecision(policy: .metadataOnly, category: .messaging, reason: "Messaging context is metadata-only", isSensitive: false)
            Logger.log("Privacy", "Decision for \(metadata.activeAppName): \(decision.policy.rawValue) reason=\(decision.reason)")
            return decision
        }

        if isVideo(title: title, appName: appName) {
            decision = PrivacyDecision(policy: .redactedScreenshot, category: .video, reason: "Video content allows redacted screenshots", isSensitive: false)
            Logger.log("Privacy", "Decision for \(metadata.activeAppName): \(decision.policy.rawValue) reason=\(decision.reason)")
            return decision
        }

        if isSocial(title: title, appName: appName) {
            decision = PrivacyDecision(policy: .redactedScreenshot, category: .socialMedia, reason: "Social content allows redacted screenshots", isSensitive: false)
            Logger.log("Privacy", "Decision for \(metadata.activeAppName): \(decision.policy.rawValue) reason=\(decision.reason)")
            return decision
        }

        if settings.allowedNormalScreenshotApps.contains(where: { appName.contains($0.lowercased()) }) {
            decision = PrivacyDecision(policy: .normalScreenshot, category: .productivity, reason: "User allowlisted normal screenshots for this app", isSensitive: false)
            Logger.log("Privacy", "Decision for \(metadata.activeAppName): \(decision.policy.rawValue) reason=\(decision.reason)")
            return decision
        }

        let category = classifyDefaultCategory(title: title, appName: appName)
        decision = PrivacyDecision(policy: .redactedScreenshot, category: category, reason: "Default to redacted screenshots", isSensitive: false)
        Logger.log("Privacy", "Decision for \(metadata.activeAppName): \(decision.policy.rawValue) reason=\(decision.reason)")
        return decision
    }

    private func classifyDefaultCategory(title: String, appName: String) -> ActivityCategory {
        if title.contains("notion") || appName.contains("notion") || appName.contains("figma") {
            return .productivity
        }
        if appName.contains("chrome") || appName.contains("safari") || appName.contains("arc") || appName.contains("firefox") {
            return .browsing
        }
        return .unknown
    }

    private func classifyBrowserCategory(title: String) -> ActivityCategory {
        if title.contains("docs") || title.contains("notion") || title.contains("figma") {
            return .productivity
        }
        if title.contains("github") || title.contains("stackoverflow") || title.contains("documentation") {
            return .research
        }
        if title.hasSuffix(" / x") || title.contains(" / x:") || title.contains("on x:") || title.contains("twitter") || title.contains("instagram") || title.contains("reddit") || title.contains("tiktok") || title.contains("facebook") || title.contains("linkedin") || title.contains(": r/") || title.contains("/r/") {
            return .socialMedia
        }
        if title.contains("youtube") || title.contains("youtu.be") || title.contains("netflix") || title.contains("twitch") {
            return .video
        }
        return .browsing
    }

    private func isBrowserApp(bundleIdentifier: String, appName: String) -> Bool {
        bundleIdentifier.contains("com.google.chrome") ||
        bundleIdentifier.contains("company.thebrowser.browser") ||
        bundleIdentifier.contains("org.mozilla.firefox") ||
        bundleIdentifier.contains("com.apple.safari") ||
        bundleIdentifier.contains("com.operasoftware") ||
        appName.contains("chrome") ||
        appName.contains("safari") ||
        appName.contains("arc") ||
        appName.contains("firefox") ||
        appName.contains("opera")
    }

    private func isPrivateWindow(title: String) -> Bool {
        ["incognito", "private browsing", "private window"].contains { title.contains($0) }
    }

    private func isCodeEditor(bundleIdentifier: String, appName: String) -> Bool {
        bundleIdentifier.contains("com.microsoft.vscode") ||
        bundleIdentifier.contains("com.jetbrains") ||
        appName.contains("xcode") ||
        appName.contains("visual studio code") ||
        appName.contains("cursor")
    }

    private func isTerminal(bundleIdentifier: String, appName: String) -> Bool {
        appName.contains("terminal") ||
        appName.contains("iterm") ||
        bundleIdentifier.contains("com.googlecode.iterm2") ||
        bundleIdentifier.contains("com.mitchellh.ghostty")
    }

    private func isEmail(title: String, appName: String) -> Bool {
        title.contains("gmail") ||
        title.contains("mail.google.com") ||
        appName == "mail" ||
        appName.contains("outlook") ||
        appName.contains("superhuman")
    }

    private func isPrivateMessaging(bundleIdentifier: String, appName: String) -> Bool {
        appName.contains("slack") ||
        appName.contains("telegram") ||
        appName.contains("whatsapp") ||
        appName.contains("messages") ||
        bundleIdentifier.contains("com.tinyspeck.slackmacgap")
    }

    private func isPaymentOrBanking(title: String, appName: String, settings: AppSettings) -> Bool {
        let keywords = [
            "payment", "checkout", "stripe", "razorpay", "paypal", "upi", "bank",
            "netbanking", "card", "cvv", "otp", "billing", "invoice payment"
        ] + settings.userSensitiveTitleKeywords.map { $0.lowercased() }

        return keywords.contains { keyword in
            title.contains(keyword) || appName.contains(keyword)
        }
    }

    private func isPasswordManager(bundleIdentifier: String, appName: String) -> Bool {
        appName.contains("1password") ||
        appName.contains("bitwarden") ||
        appName.contains("lastpass") ||
        appName.contains("dashlane") ||
        appName.contains("keeper") ||
        bundleIdentifier.contains("1password")
    }

    private func isVideo(title: String, appName: String) -> Bool {
        appName.contains("youtube") || title.contains("youtube") || title.contains("youtu.be")
    }

    private func isSocial(title: String, appName: String) -> Bool {
        ["instagram", "reddit", "x.com", "twitter", "facebook", "linkedin", "tiktok", "mastodon", "threads"].contains { keyword in
            title.contains(keyword) || appName.contains(keyword)
        } || title.hasSuffix(" / x") || title.contains(" / x:") || title.contains("on x:") || title.contains(": r/") || title.contains("/r/")
    }
}

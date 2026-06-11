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

        if isBrowserApp(bundleIdentifier: bundleIdentifier, appName: appName) {
            if isPrivateWindow(title: title) {
                return PrivacyDecision(policy: .noCapture, category: .browsing, reason: "Private or incognito browser window detected", isSensitive: true)
            }

            if isPaymentOrBanking(title: title, appName: appName, settings: settings) {
                return PrivacyDecision(policy: .noCapture, category: .payment, reason: "Payment or banking page detected in browser", isSensitive: true)
            }

            if isEmail(title: title, appName: appName) {
                return PrivacyDecision(policy: .metadataOnly, category: .email, reason: "Email page in browser is metadata-only", isSensitive: false)
            }

            if isVideo(title: title, appName: appName) {
                return PrivacyDecision(policy: .redactedScreenshot, category: .video, reason: "Browser video page stores redacted screenshots", isSensitive: false)
            }

            if isSocial(title: title, appName: appName) {
                return PrivacyDecision(policy: .redactedScreenshot, category: .socialMedia, reason: "Browser social page stores redacted screenshots", isSensitive: false)
            }

            let category = classifyBrowserCategory(title: title)
            return PrivacyDecision(policy: .redactedScreenshot, category: category, reason: "Browser context stores redacted screenshots by default", isSensitive: false)
        }

        if isPasswordManager(bundleIdentifier: bundleIdentifier, appName: appName) {
            return PrivacyDecision(policy: .noCapture, category: .productivity, reason: "Password manager detected", isSensitive: true)
        }

        if isPrivateWindow(title: title) {
            return PrivacyDecision(policy: .noCapture, category: .browsing, reason: "Private or incognito window detected", isSensitive: true)
        }

        if isPaymentOrBanking(title: title, appName: appName, settings: settings) {
            return PrivacyDecision(policy: .noCapture, category: .payment, reason: "Payment or banking context detected", isSensitive: true)
        }

        if isCodeEditor(bundleIdentifier: bundleIdentifier, appName: appName) {
            return PrivacyDecision(policy: .metadataOnly, category: .coding, reason: "Code editor is metadata-only", isSensitive: false)
        }

        if isTerminal(bundleIdentifier: bundleIdentifier, appName: appName) {
            return PrivacyDecision(policy: .metadataOnly, category: .coding, reason: "Terminal is metadata-only", isSensitive: false)
        }

        if isEmail(title: title, appName: appName) {
            return PrivacyDecision(policy: .metadataOnly, category: .email, reason: "Email context is metadata-only", isSensitive: false)
        }

        if isPrivateMessaging(bundleIdentifier: bundleIdentifier, appName: appName) {
            return PrivacyDecision(policy: .metadataOnly, category: .messaging, reason: "Messaging context is metadata-only", isSensitive: false)
        }

        if isVideo(title: title, appName: appName) {
            return PrivacyDecision(policy: .redactedScreenshot, category: .video, reason: "Video content allows redacted screenshots", isSensitive: false)
        }

        if isSocial(title: title, appName: appName) {
            return PrivacyDecision(policy: .redactedScreenshot, category: .socialMedia, reason: "Social content allows redacted screenshots", isSensitive: false)
        }

        if settings.allowedNormalScreenshotApps.contains(where: { appName.contains($0.lowercased()) }) {
            return PrivacyDecision(policy: .normalScreenshot, category: .productivity, reason: "User allowlisted normal screenshots for this app", isSensitive: false)
        }

        let category = classifyDefaultCategory(title: title, appName: appName)
        return PrivacyDecision(policy: .redactedScreenshot, category: category, reason: "Default to redacted screenshots", isSensitive: false)
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
        if title.contains("github") || title.contains("stackoverflow") || title.contains("documentation") || title.contains("docs") {
            return .research
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
        ["instagram", "reddit", "x.com", "twitter", "facebook", "linkedin"].contains { keyword in
            title.contains(keyword) || appName.contains(keyword)
        }
    }
}

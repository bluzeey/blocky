import Combine
import AppKit
import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var settings: AppSettings
    @Published var sessionDraft = SessionDraft()
    @Published var activeSession: IntentionSession?
    @Published var currentMetadata: WindowMetadata?
    @Published var currentDecision: PrivacyDecision?
    @Published var currentAlignment: Alignment = .unknown
    @Published var recentEvents: [ContextEvent] = []
    @Published var permissionSnapshot = PermissionSnapshot.empty
    @Published var aiStatusMessage = "AI review idle"
    @Published var latestNudgeMessage = "No recent nudge"
    @Published var isRunningTrackingLoop = false
    @Published var driftSnoozeUntil: Date?

    let settingsStore: AppSettingsStore
    let permissionManager: PermissionManager
    let sessionManager: IntentionSessionManager
    let windowMetadataService: WindowMetadataService
    let privacyPolicyEngine = PrivacyPolicyEngine()
    let captureLibraryStore: CaptureLibraryStore

    private let captureCoordinator: CaptureCoordinator
    private let aiPayloadBuilder = AIPayloadBuilder()
    private let aiClient = AIClient()
    private let notificationManager: NotificationManager
    private let nudgeService: NudgeService

    private var trackingTask: Task<Void, Never>?
    private var aiReviewTask: Task<Void, Never>?
    private var lastAIReviewDate: Date?
    private var lastNudgeShownDate: Date?
    private var lastAIAlignmentCheckDate: Date?
    private var lastPeriodicNudgeDate: Date?
    private var lifecycleCancellables = Set<AnyCancellable>()
    private let intentionPanelController = IntentionPanelController()
    private let nudgePanelController = NudgePanelController()

    init() {
        let settingsStore = AppSettingsStore()
        let captureLibraryStore = CaptureLibraryStore()
        let notificationManager = NotificationManager()
        self.settingsStore = settingsStore
        self.settings = settingsStore.settings
        self.captureLibraryStore = captureLibraryStore
        self.permissionManager = PermissionManager()
        self.sessionManager = IntentionSessionManager()
        self.windowMetadataService = WindowMetadataService()
        self.captureCoordinator = CaptureCoordinator()
        self.notificationManager = notificationManager
        self.nudgeService = NudgeService(notificationManager: notificationManager)
        notificationManager.setupDelegate()
        observeApplicationLifecycle()
        nudgeService.appState = self
        Logger.log("AppState", "Initialized AppState")
        Task { [weak self] in
            await self?.startIfNeeded()
        }
    }

    func refreshSettings() {
        settings = settingsStore.settings
        Logger.log("AppState", "Refreshed settings from store")
    }

    func refreshPermissions() async {
        permissionSnapshot = await permissionManager.refreshSnapshot()
        Logger.log("AppState", "Permission snapshot updated")
    }

    func startIfNeeded() async {
        guard trackingTask == nil, aiReviewTask == nil else { return }
        try? captureLibraryStore.reload()
        await refreshPermissions()
        isRunningTrackingLoop = true
        Logger.log("AppState", "Starting tracking and AI review loops")

        if activeSession == nil {
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard let self, self.activeSession == nil else { return }
                self.showIntentionModal()
            }
        }

        trackingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.refreshPermissions()
                if let activeSession = self.activeSession, !activeSession.isPaused {
                    await self.performTrackingTick()
                }
                try? await Task.sleep(nanoseconds: UInt64(max(1, self.settings.metadataPollIntervalSeconds)) * 1_000_000_000)
            }
        }

        aiReviewTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                if let activeSession = self.activeSession, !activeSession.isPaused {
                    await self.performAIAlignmentCheck(session: activeSession)
                }
                try? await Task.sleep(nanoseconds: UInt64(max(60, self.settings.aiReviewIntervalSeconds)) * 1_000_000_000)
            }
        }
    }

    func saveSettings(_ settings: AppSettings) {
        settingsStore.replace(with: settings)
        refreshSettings()
        Logger.log("AppState", "Saved settings")
    }

    func startSessionFromDraft() {
        let session = sessionDraft.buildSession(reviewIntervalSeconds: settings.aiReviewIntervalSeconds)
        activeSession = session
        latestNudgeMessage = "Session started"
        lastAIReviewDate = nil
        recentEvents.removeAll()
        hideIntentionModal()
        Logger.log("Session", "Started session id=\(session.id.uuidString) title=\(session.title)")
    }

    func togglePauseSession() {
        guard let activeSession else { return }
        self.activeSession = activeSession.isPaused ? sessionManager.resume(activeSession) : sessionManager.pause(activeSession)
        Logger.log("Session", "Toggled pause. paused=\(self.activeSession?.isPaused == true)")
    }

    func endSession() {
        Logger.log("Session", "Ended session id=\(activeSession?.id.uuidString ?? "nil")")
        activeSession = nil
        driftSnoozeUntil = nil
        latestNudgeMessage = "Session ended"
        nudgePanelController.hide()
    }

    func allowDriftForFiveMinutes() {
        driftSnoozeUntil = Date().addingTimeInterval(5 * 60)
        latestNudgeMessage = "Five-minute drift allowance enabled"
        Logger.log("Session", "Enabled five-minute drift allowance until \(driftSnoozeUntil?.description ?? "nil")")
    }

    func showIntentionModal() {
        intentionPanelController.show(appState: self)
    }

    func hideIntentionModal() {
        intentionPanelController.hide()
    }

    func showNudgePopup(sessionTitle: String, message: String) {
        lastNudgeShownDate = Date()
        nudgePanelController.show(appState: self, sessionTitle: sessionTitle, message: message)
    }

    func acknowledgeNudge(isOnTrack: Bool) {
        nudgePanelController.hide()
        if isOnTrack {
            latestNudgeMessage = "On track"
            lastPeriodicNudgeDate = Date()
            Logger.log("Nudge", "User acknowledged on track")
        } else {
            currentAlignment = .drift
            latestNudgeMessage = "Self-reported drift"
            Logger.log("Nudge", "User self-reported drift, showing intention modal")
            showIntentionModal()
        }
    }

    func requestAccessibilityPermission() {
        _ = permissionManager.requestAccessibilityPermission()
        Task { [weak self] in
            _ = await self?.permissionManager.pollAccessibility()
            await self?.refreshPermissions()
        }
    }

    func requestScreenRecordingPermission() {
        _ = permissionManager.requestScreenRecordingPermission()
        Task { [weak self] in
            _ = await self?.permissionManager.pollScreenRecording()
            await self?.refreshPermissions()
        }
    }

    func requestNotificationPermission() async {
        NSApplication.shared.activate(ignoringOtherApps: true)
        _ = await permissionManager.requestNotificationPermission()
        await refreshPermissions()
    }

    func deleteAllCaptures() {
        do {
            try captureLibraryStore.deleteAll()
            Logger.log("AppState", "Deleted all captures from UI action")
        } catch {
            latestNudgeMessage = "Failed to delete captures: \(error.localizedDescription)"
            Logger.log("AppState", "Failed to delete captures: \(error.localizedDescription)")
        }
    }

    private func performTrackingTick() async {
        guard let metadata = windowMetadataService.currentWindowMetadata(), let activeSession else {
            Logger.log("Tracking", "Skipping tracking tick because metadata or session is missing")
            return
        }

        Logger.log("Tracking", "Tracking tick for app=\(metadata.activeAppName) title=\(metadata.windowTitle ?? "nil")")

        let privacyDecision = privacyPolicyEngine.decidePolicy(for: metadata, settings: settings)
        var alignment = sessionManager.evaluateAlignment(
            session: activeSession,
            metadata: metadata,
            category: privacyDecision.category,
            privacyDecision: privacyDecision,
            settings: settings
        )

        if let driftSnoozeUntil, driftSnoozeUntil > Date(), alignment == .drift {
            alignment = .neutral
            Logger.log("Tracking", "Drift was snoozed; alignment downgraded to neutral")
        }

        let processingResult = await captureCoordinator.process(
            metadata: metadata,
            privacyDecision: privacyDecision,
            alignment: alignment,
            settings: settings,
            permissionSnapshot: permissionSnapshot
        )

        let recordID = UUID()
        let previewPath = processingResult.previewData == nil || !settings.storeRedactedPreviews
            ? nil
            : captureLibraryStore.previewPath(for: recordID, timestamp: metadata.timestamp)

        let captureRecord = CaptureRecord(
            id: recordID,
            timestamp: metadata.timestamp,
            activeAppName: metadata.activeAppName,
            bundleIdentifier: metadata.bundleIdentifier,
            windowTitle: metadata.windowTitle,
            capturePolicy: privacyDecision.policy,
            activityCategory: privacyDecision.category,
            alignment: alignment,
            redactedPreviewPath: previewPath,
            rawScreenshotStored: false,
            safeSummary: processingResult.safeSummary,
            aiPayloadPath: nil,
            skippedReason: processingResult.skippedReason,
            redactionReasons: processingResult.redactionReasons,
            sentToAI: false,
            privacyDecisionReason: privacyDecision.reason
        )

        do {
            try captureLibraryStore.saveCaptureRecord(captureRecord, previewData: settings.storeRedactedPreviews ? processingResult.previewData : nil)
        } catch {
            Logger.log("AppState", "Failed to store capture record: \(error.localizedDescription)")
        }

        let contextEvent = ContextEvent(
            id: UUID(),
            timestamp: metadata.timestamp,
            metadata: metadata,
            capturePolicy: privacyDecision.policy,
            category: privacyDecision.category,
            safeSummary: processingResult.safeSummary,
            alignment: alignment,
            captureRecordID: captureRecord.id
        )

        recentEvents.append(contextEvent)
        recentEvents = Array(recentEvents.suffix(500))

        currentMetadata = metadata
        currentDecision = privacyDecision
        let previousAlignment = currentAlignment
        currentAlignment = alignment
        Logger.log("Tracking", "Tracking tick completed with alignment=\(alignment.rawValue) policy=\(privacyDecision.policy.rawValue)")

        if alignment == .drift, previousAlignment != .drift {
            if let lastNudgeShownDate, Date().timeIntervalSince(lastNudgeShownDate) < 60 {
                Logger.log("Tracking", "Drift detected but nudge shown recently, skipping popup")
            } else {
                Logger.log("Tracking", "Drift detected, showing nudge popup")
                showNudgePopup(sessionTitle: activeSession.title, message: "You seem to have drifted from your intention. Are you on track?")
            }
        }

        let nudgeIntervalSeconds = max(60, settings.aiReviewIntervalSeconds)
        if self.lastPeriodicNudgeDate != nil {
            if let lastPeriodicNudgeDate, Date().timeIntervalSince(lastPeriodicNudgeDate) >= TimeInterval(nudgeIntervalSeconds) {
                if let lastNudgeShownDate, Date().timeIntervalSince(lastNudgeShownDate) < 60 {
                    Logger.log("Tracking", "Periodic nudge skipped: nudge shown recently")
                } else {
                    Logger.log("Tracking", "Periodic nudge timer fired")
                    showNudgePopup(sessionTitle: activeSession.title, message: "Are you still on track?")
                    self.lastPeriodicNudgeDate = Date()
                }
            }
        } else {
            self.lastPeriodicNudgeDate = Date()
        }

        if sessionManager.isExpired(activeSession) {
            endSession()
        }
    }

    private func performAIAlignmentCheck(session: IntentionSession) async {
        let now = Date()
        let interval = TimeInterval(max(60, settings.aiReviewIntervalSeconds))

        if let lastAIAlignmentCheckDate, now.timeIntervalSince(lastAIAlignmentCheckDate) < interval {
            return
        }

        if !settings.hasAIConfiguration {
            return
        }

        let recentApps = recentEvents.suffix(20).map { (app: $0.metadata.activeAppName, title: $0.metadata.windowTitle ?? "Unknown") }
        guard !recentApps.isEmpty else {
            Logger.log("AI", "Skipping alignment check: no recent events")
            return
        }

        aiStatusMessage = "Checking alignment..."
        Logger.log("AI", "Starting lightweight alignment check")

        do {
            let response = try await aiClient.checkAlignment(
                intention: session.title,
                recentApps: recentApps,
                settings: settings
            )

            lastAIAlignmentCheckDate = now
            currentAlignment = response.alignment
            aiStatusMessage = "Last check: \(response.alignment.rawValue)"
            latestNudgeMessage = response.message
            Logger.log("AI", "Alignment check completed: alignment=\(response.alignment.rawValue) message=\(response.message)")

            if response.alignment == .drift || response.alignment == .sensitive {
                if let lastNudgeShownDate, Date().timeIntervalSince(lastNudgeShownDate) < 60 {
                    Logger.log("AI", "AI detected drift but nudge shown recently, skipping popup")
                } else {
                    showNudgePopup(sessionTitle: session.title, message: response.message)
                }
            }
        } catch {
            aiStatusMessage = "AI check failed: \(error.localizedDescription)"
            Logger.log("AI", "AI alignment check failed: \(error.localizedDescription)")
        }
    }

    private func observeApplicationLifecycle() {
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.refreshPermissions()
                }
            }
            .store(in: &lifecycleCancellables)
    }
}

private extension JSONEncoder {
    static var prettyPrinted: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

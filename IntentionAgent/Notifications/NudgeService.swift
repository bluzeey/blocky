import Foundation

@MainActor
final class NudgeService {
    private let notificationManager: NotificationManager
    weak var appState: AppState?

    init(notificationManager: NotificationManager) {
        self.notificationManager = notificationManager
    }

    func handleReviewResponse(_ response: AIReviewResponse, session: IntentionSession) async {
        guard response.alignment == .drift || response.alignment == .sensitive else { return }
        appState?.showNudgePopup(sessionTitle: session.title, message: response.message)
        await notificationManager.send(title: session.title, body: response.message)
    }
}

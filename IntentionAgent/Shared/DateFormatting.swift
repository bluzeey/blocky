import Foundation

enum DateFormatting {
    static let captureTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()

    static let dayFolderFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let jsonTimestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

extension Date {
    var captureTimeText: String {
        DateFormatting.captureTimeFormatter.string(from: self)
    }

    var dayFolderComponent: String {
        DateFormatting.dayFolderFormatter.string(from: self)
    }
}

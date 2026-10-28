import Foundation

/// Exported PDFs live only in a protected temp folder, and only until the share finishes.
enum ExportFiles {
    static var directory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("Exports", isDirectory: true)
    }

    /// The file name holds no PHI: only the week's start date.
    static func write(_ data: Data, weekStart: Date) throws -> URL {
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete]
        )
        let parts = DischargeWeek.calendar.dateComponents([.year, .month, .day], from: weekStart)
        let day = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        let url = directory.appendingPathComponent("Discharge list week of \(day).pdf")
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }

    static func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    static func removeAll() {
        try? FileManager.default.removeItem(at: directory)
    }
}

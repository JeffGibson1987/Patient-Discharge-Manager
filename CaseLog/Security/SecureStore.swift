import Foundation
import LocalAuthentication
import SwiftData

/// Builds the on-device database with the protections the plan calls for:
/// iOS Data Protection "Complete" (unreadable while the phone is locked),
/// excluded from iCloud and Finder backups, and never synced through CloudKit.
enum SecureStore {
    static let schema = Schema([SurgicalCase.self, PostOpEvent.self, AuditEvent.self])

    static func makeContainer() throws -> ModelContainer {
        let directory = try storeDirectory()
        let configuration = ModelConfiguration(
            "CaseLog",
            schema: schema,
            url: directory.appendingPathComponent("CaseLog.store"),
            allowsSave: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private static func storeDirectory() throws -> URL {
        let fileManager = FileManager.default
        var directory = try fileManager
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("CaseLogStore", isDirectory: true)
        let protection: [FileAttributeKey: Any] = [.protectionKey: FileProtectionType.complete]
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: protection)
        try fileManager.setAttributes(protection, ofItemAtPath: directory.path)

        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        return directory
    }
}

enum DeviceSecurity {
    /// Data Protection only encrypts files when the phone has a passcode,
    /// so the app refuses to show PHI without one.
    static var isPasscodeSet: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }
}

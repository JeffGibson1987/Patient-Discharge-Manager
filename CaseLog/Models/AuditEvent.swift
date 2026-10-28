import Foundation
import SwiftData

/// An entry in the on-device audit log. Holds no PHI itself: only the action,
/// the time, and the case's random id.
@Model
final class AuditEvent {
    var timestamp: Date
    var actionRaw: String
    var caseID: UUID?
    var detail: String

    init(action: AuditAction, caseID: UUID? = nil, detail: String = "") {
        self.timestamp = .now
        self.actionRaw = action.rawValue
        self.caseID = caseID
        self.detail = detail
    }

    var action: AuditAction { AuditAction(rawValue: actionRaw) ?? .view }
}

enum AuditAction: String, CaseIterable, Codable {
    case unlock = "Unlock"
    case unlockFailed = "Unlock failed"
    case view = "View"
    case create = "Create"
    case edit = "Edit"
    case delete = "Delete"
    case restore = "Restore"
    case purge = "Purge"
    case export = "Export"
}

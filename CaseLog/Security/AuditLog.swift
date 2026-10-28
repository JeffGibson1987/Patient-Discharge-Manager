import Foundation
import SwiftData

enum AuditLog {
    /// Records an action and saves any pending changes with it.
    static func record(_ action: AuditAction, caseID: UUID? = nil, detail: String = "", in context: ModelContext) {
        context.insert(AuditEvent(action: action, caseID: caseID, detail: detail))
        do {
            try context.save()
        } catch {
            assertionFailure("Audit save failed: \(error)")
        }
    }
}

enum Maintenance {
    /// Permanently removes cases that have been in Recently Deleted longer than the undo window.
    static func purgeExpiredCases(in context: ModelContext, now: Date = .now) {
        let descriptor = FetchDescriptor<SurgicalCase>(predicate: #Predicate { $0.deletedAt != nil })
        guard let deleted = try? context.fetch(descriptor) else { return }
        let expired = deleted.filter { caseItem in
            guard let deletedAt = caseItem.deletedAt else { return false }
            return now.timeIntervalSince(deletedAt) > SurgicalCase.undoWindow
        }
        for caseItem in expired {
            let id = caseItem.id
            context.delete(caseItem)
            context.insert(AuditEvent(action: .purge, caseID: id))
        }
        if !expired.isEmpty {
            try? context.save()
        }
    }
}

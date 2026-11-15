import Foundation
import SwiftData

/// Version 1 of the database layout.
///
/// Every later change to a stored property of SurgicalCase, PostOpEvent or AuditEvent
/// needs a new version, so the cases already on the phone are carried forward:
///  1. Copy the current model classes, unchanged, inside `CaseLogSchemaV1` as a frozen snapshot.
///  2. Add `CaseLogSchemaV2` listing the changed classes.
///  3. Append it to `CaseLogMigrationPlan.schemas`, and add a stage (`.lightweight` for added
///     optional fields, `.custom` when existing values need converting).
enum CaseLogSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [SurgicalCase.self, PostOpEvent.self, AuditEvent.self]
    }
}

enum CaseLogMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [CaseLogSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}

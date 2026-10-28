import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppLock.timeoutKey) private var lockTimeout: Double = AppLock.defaultTimeout
    @AppStorage(CaseDefaults.surgeonKey) private var defaultSurgeon: String = ReferenceData.surgeons[0]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Lock after", selection: $lockTimeout) {
                        Text("Immediately").tag(1.0)
                        Text("1 minute").tag(60.0)
                        Text("2 minutes").tag(120.0)
                        Text("5 minutes").tag(300.0)
                    }
                } header: {
                    Text("Security")
                } footer: {
                    Text("How long Case Log can stay in the background before it asks for Face ID again.")
                }

                Section("New cases") {
                    Picker("Default surgeon", selection: $defaultSurgeon) {
                        ForEach(ReferenceData.surgeons, id: \.self) { Text($0).tag($0) }
                    }
                }

                Section("Records") {
                    NavigationLink("Recently deleted") { RecentlyDeletedView() }
                    NavigationLink("Audit log") { AuditLogView() }
                }

                Section {
                    Text("Cases are stored only on this iPhone, encrypted by iOS, and left out of iCloud and computer backups. If you delete Case Log, its cases are deleted too.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct RecentlyDeletedView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<SurgicalCase> { $0.deletedAt != nil }, sort: \SurgicalCase.surgeryDate, order: .reverse)
    private var deleted: [SurgicalCase]

    var body: some View {
        List {
            ForEach(deleted) { caseItem in
                CaseRow(caseItem: caseItem)
                    .swipeActions {
                        Button {
                            caseItem.deletedAt = nil
                            AuditLog.record(.restore, caseID: caseItem.id, in: context)
                        } label: {
                            Label("Restore", systemImage: "arrow.uturn.backward")
                        }
                        .tint(.blue)
                    }
            }
        }
        .overlay {
            if deleted.isEmpty {
                ContentUnavailableView("Nothing deleted", systemImage: "trash")
            }
        }
        .navigationTitle("Recently deleted")
        .safeAreaInset(edge: .bottom) {
            Text("Deleted cases are removed permanently after 30 days. Swipe left to restore.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding()
        }
    }
}

struct AuditLogView: View {
    @Query(sort: \AuditEvent.timestamp, order: .reverse)
    private var events: [AuditEvent]

    var body: some View {
        List(events.prefix(500)) { event in
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(event.action.rawValue)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(event.timestamp.formatted(date: .abbreviated, time: .standard))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let caseID = event.caseID {
                    Text("Case \(caseID.uuidString.prefix(8))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !event.detail.isEmpty {
                    Text(event.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Audit log")
    }
}

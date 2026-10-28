import SwiftData
import SwiftUI

struct CaseListView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<SurgicalCase> { $0.deletedAt == nil }, sort: \SurgicalCase.surgeryDate, order: .reverse)
    private var cases: [SurgicalCase]

    @State private var searchText = ""
    @State private var newCase: SurgicalCase?
    @State private var showingExport = false
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            List {
                if !inHospital.isEmpty {
                    Section("In hospital") {
                        ForEach(inHospital) { row($0) }
                    }
                }
                if !discharged.isEmpty {
                    Section("Discharged") {
                        ForEach(discharged) { row($0) }
                    }
                }
            }
            .overlay {
                if cases.isEmpty {
                    ContentUnavailableView(
                        "No cases yet",
                        systemImage: "heart.text.square",
                        description: Text("Tap + to log an operation.")
                    )
                } else if filtered.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .searchable(text: $searchText, prompt: "Search by name")
            .autocorrectionDisabled()
            .navigationTitle("Cases")
            .navigationDestination(for: SurgicalCase.self) { caseItem in
                CaseFormView(caseItem: caseItem, isNew: false)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingSettings = true } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showingExport = true } label: {
                        Label("Weekly discharge list", systemImage: "doc.richtext")
                    }
                    Button { newCase = SurgicalCase(surgeon: CaseDefaults.surgeon) } label: {
                        Label("New case", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $newCase) { caseItem in
                NavigationStack {
                    CaseFormView(caseItem: caseItem, isNew: true)
                }
                .interactiveDismissDisabled()
            }
            .sheet(isPresented: $showingExport) {
                DischargeExportView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }

    private var filtered: [SurgicalCase] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return cases }
        return cases.filter {
            $0.firstName.localizedCaseInsensitiveContains(query)
                || $0.lastName.localizedCaseInsensitiveContains(query)
        }
    }

    private var inHospital: [SurgicalCase] { filtered.filter { !$0.isDischarged } }
    private var discharged: [SurgicalCase] { filtered.filter { $0.isDischarged } }

    private func row(_ caseItem: SurgicalCase) -> some View {
        NavigationLink(value: caseItem) {
            CaseRow(caseItem: caseItem)
        }
        .swipeActions {
            Button(role: .destructive) {
                caseItem.deletedAt = .now
                AuditLog.record(.delete, caseID: caseItem.id, in: context)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

struct CaseRow: View {
    let caseItem: SurgicalCase

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(caseItem.displayName)
                .font(.headline)
            Text(caseItem.procedures.isEmpty ? "No procedure entered" : caseItem.procedures.joined(separator: ", "))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            HStack(spacing: 8) {
                Text("OR \(caseItem.surgeryDate.formatted(date: .abbreviated, time: .omitted))")
                if let dischargeDate = caseItem.dischargeDate {
                    Text("DC \(dischargeDate.formatted(date: .abbreviated, time: .omitted))")
                }
                if !caseItem.events.isEmpty {
                    Label("\(caseItem.events.count)", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

enum CaseDefaults {
    static let surgeonKey = "defaultSurgeon"

    static var surgeon: String {
        UserDefaults.standard.string(forKey: surgeonKey) ?? ReferenceData.surgeons[0]
    }
}

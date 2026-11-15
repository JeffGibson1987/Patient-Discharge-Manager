import SwiftData
import SwiftUI

/// Creates a new case (presented in a sheet) or edits an existing one (pushed).
struct CaseFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var caseItem: SurgicalCase
    let isNew: Bool

    @State private var editingEvent: PostOpEvent?
    @State private var addingEvent = false
    @State private var didLogView = false

    var body: some View {
        Form {
            patientSection
            surgerySection
            if !isNew {
                eventsSection
            }
            dischargeSection
            missingSection
        }
        .onChange(of: caseItem.dischargeDate) { _, newValue in
            if newValue == nil { caseItem.dischargeDestination = nil }
        }
        .navigationTitle(isNew ? "New case" : caseItem.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isNew {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveNew() }
                        .disabled(!isValid)
                }
            }
        }
        .sheet(isPresented: $addingEvent) {
            EventEditorView(event: nil) { category, subcategory, date, note in
                let event = PostOpEvent(category: category, subcategory: subcategory, dateNoted: date, note: note)
                context.insert(event)
                event.surgicalCase = caseItem
                caseItem.noPostOpEvents = false
                saveEdits()
            }
        }
        .sheet(item: $editingEvent) { event in
            EventEditorView(event: event) { category, subcategory, date, note in
                event.category = category
                event.subcategory = subcategory
                event.dateNoted = date
                event.note = note
                saveEdits()
            }
        }
        .onAppear {
            // onAppear also fires when returning from the procedure list, so log the view once.
            if !isNew && !didLogView {
                didLogView = true
                AuditLog.record(.view, caseID: caseItem.id, in: context)
            }
        }
        .onDisappear {
            if !isNew {
                saveEdits()
            }
        }
    }

    // MARK: Sections

    /// What still has to be filled in: to save a new case, or to put this one on the discharge list.
    @ViewBuilder
    private var missingSection: some View {
        let missing = isNew ? caseItem.missingRequiredFields : caseItem.missingForDischargeList
        if !missing.isEmpty {
            Section {
                Text(missing.joined(separator: ", "))
                    .foregroundStyle(.orange)
            } header: {
                Text(isNew ? "Needed to save" : "Needed for the discharge list")
            }
        }
    }

    private var patientSection: some View {
        Section("Patient") {
            TextField("First name", text: $caseItem.firstName)
                .autocorrectionDisabled()
            TextField("Last name", text: $caseItem.lastName)
                .autocorrectionDisabled()
            DateEntryField(title: "Date of birth", date: $caseItem.dateOfBirth)
            Picker("Gender", selection: $caseItem.gender) {
                ForEach(Gender.allCases) { Text($0.label).tag(Optional($0)) }
            }
            .pickerStyle(.segmented)
            LabeledContent("Age at surgery", value: caseItem.ageAtSurgery.map { "\($0)" } ?? "–")
        }
    }

    private var surgerySection: some View {
        Section("Surgery") {
            OptionalDateRow(title: "Surgery date", date: $caseItem.surgeryDate, setButtonTitle: "Today", latest: caseItem.dischargeDate)
            Picker("Surgeon", selection: $caseItem.surgeon) {
                ForEach(surgeonChoices, id: \.self) { Text($0).tag($0) }
            }
            TextField("Referring provider", text: $caseItem.referringProvider)
                .autocorrectionDisabled()
            NavigationLink {
                ProcedurePickerView(selection: $caseItem.procedures)
            } label: {
                LabeledContent("Procedures") {
                    if caseItem.procedures.isEmpty {
                        Text("Required").foregroundStyle(.red)
                    } else {
                        Text(caseItem.procedures.joined(separator: ", "))
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
        }
    }

    private var eventsSection: some View {
        Section {
            ForEach(caseItem.sortedEvents) { event in
                Button { editingEvent = event } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.summary)
                            .foregroundStyle(.primary)
                        Text(event.dateNoted.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { offsets in
                let events = caseItem.sortedEvents
                for index in offsets {
                    context.delete(events[index])
                }
                saveEdits()
            }
            if caseItem.events.isEmpty {
                Toggle("None", isOn: $caseItem.noPostOpEvents)
            }
            Button {
                addingEvent = true
            } label: {
                Label("Add post-op event", systemImage: "plus")
            }
        } header: {
            Text("Post-op events")
        } footer: {
            if caseItem.events.isEmpty && !caseItem.noPostOpEvents {
                Text("Turn on None or add an event. The case can't go on the discharge list until this is answered.")
            }
        }
    }

    private var dischargeSection: some View {
        Section {
            OptionalDateRow(
                title: "Discharge date",
                date: $caseItem.dischargeDate,
                emptyText: "In hospital",
                emptyIsError: false,
                setButtonTitle: "Discharge",
                earliest: caseItem.surgeryDate,
                canClear: true
            )
            if caseItem.dischargeDate != nil {
                Picker("Destination", selection: $caseItem.dischargeDestination) {
                    Text("Select").tag(DischargeDestination?.none)
                    ForEach(DischargeDestination.allCases) { Text($0.label).tag(Optional($0)) }
                }
                TextField("Discharge notes", text: $caseItem.dischargeNotes, axis: .vertical)
                    .lineLimit(2...6)
            }
        } header: {
            Text("Discharge")
        } footer: {
            Text(isNew
                ? "Save the case first, then add post-op events. Don't put MRNs, addresses or phone numbers in notes."
                : "Don't put MRNs, addresses or phone numbers in notes.")
        }
    }

    private var surgeonChoices: [String] {
        var choices = ReferenceData.surgeons
        if !caseItem.surgeon.isEmpty, !choices.contains(caseItem.surgeon) {
            choices.append(caseItem.surgeon)
        }
        return choices
    }

    // MARK: Saving

    private var isValid: Bool {
        caseItem.missingRequiredFields.isEmpty
    }

    private func saveNew() {
        caseItem.firstName = caseItem.firstName.trimmingCharacters(in: .whitespaces)
        caseItem.lastName = caseItem.lastName.trimmingCharacters(in: .whitespaces)
        context.insert(caseItem)
        AuditLog.record(.create, caseID: caseItem.id, in: context)
        dismiss()
    }

    private func saveEdits() {
        guard context.hasChanges else { return }
        caseItem.updatedAt = .now
        AuditLog.record(.edit, caseID: caseItem.id, in: context)
    }
}

struct ProcedurePickerView: View {
    @Binding var selection: [String]

    var body: some View {
        List(ReferenceData.procedures, id: \.self) { procedure in
            Button {
                if let index = selection.firstIndex(of: procedure) {
                    selection.remove(at: index)
                } else {
                    selection.append(procedure)
                }
            } label: {
                HStack {
                    Text(procedure)
                        .foregroundStyle(.primary)
                    Spacer()
                    if selection.contains(procedure) {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                    }
                }
            }
        }
        .navigationTitle("Procedures")
        .navigationBarTitleDisplayMode(.inline)
    }
}

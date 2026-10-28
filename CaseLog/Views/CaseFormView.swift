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

    private var patientSection: some View {
        Section("Patient") {
            TextField("First name", text: $caseItem.firstName)
                .autocorrectionDisabled()
            TextField("Last name", text: $caseItem.lastName)
                .autocorrectionDisabled()
            DatePicker("Date of birth", selection: $caseItem.dateOfBirth, in: ...Date.now, displayedComponents: .date)
            Picker("Gender", selection: $caseItem.gender) {
                ForEach(Gender.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            LabeledContent("Age at surgery", value: "\(caseItem.ageAtSurgery)")
        }
    }

    private var surgerySection: some View {
        Section("Surgery") {
            DatePicker("Surgery date", selection: $caseItem.surgeryDate, displayedComponents: .date)
            Picker("Surgeon", selection: $caseItem.surgeon) {
                ForEach(surgeonChoices, id: \.self) { Text($0).tag($0) }
            }
            TextField("Referring provider", text: $caseItem.referringProvider)
                .autocorrectionDisabled()
            NavigationLink {
                ProcedurePickerView(selection: $caseItem.procedures)
            } label: {
                LabeledContent("Procedures") {
                    Text(caseItem.procedures.isEmpty ? "None" : caseItem.procedures.joined(separator: ", "))
                        .multilineTextAlignment(.trailing)
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
            Button {
                addingEvent = true
            } label: {
                Label("Add post-op event", systemImage: "plus")
            }
        } header: {
            Text("Post-op events")
        }
    }

    private var dischargeSection: some View {
        Section {
            Toggle("Discharged", isOn: isDischarged)
            if caseItem.dischargeDate != nil {
                DatePicker("Discharge date", selection: dischargeDate, in: caseItem.surgeryDate..., displayedComponents: .date)
                Picker("Destination", selection: dischargeDestination) {
                    ForEach(DischargeDestination.allCases) { Text($0.rawValue).tag($0) }
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

    // MARK: Bindings for optional discharge fields

    private var isDischarged: Binding<Bool> {
        Binding(
            get: { caseItem.dischargeDate != nil },
            set: { discharged in
                if discharged {
                    caseItem.dischargeDate = max(Date.now, caseItem.surgeryDate)
                    if caseItem.dischargeDestination == nil {
                        caseItem.dischargeDestination = .home
                    }
                } else {
                    caseItem.dischargeDate = nil
                    caseItem.dischargeDestination = nil
                }
            }
        )
    }

    private var dischargeDate: Binding<Date> {
        Binding(
            get: { caseItem.dischargeDate ?? .now },
            set: { caseItem.dischargeDate = $0 }
        )
    }

    private var dischargeDestination: Binding<DischargeDestination> {
        Binding(
            get: { caseItem.dischargeDestination ?? .home },
            set: { caseItem.dischargeDestination = $0 }
        )
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
        !caseItem.firstName.trimmingCharacters(in: .whitespaces).isEmpty
            && !caseItem.lastName.trimmingCharacters(in: .whitespaces).isEmpty
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

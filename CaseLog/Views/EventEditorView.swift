import SwiftUI

/// Adds or edits one post-op event. Calls `onSave` with the chosen values.
struct EventEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (_ category: String, _ subcategory: String?, _ date: Date, _ note: String) -> Void

    @State private var category: String
    @State private var subcategory: String
    @State private var dateNoted: Date
    @State private var note: String
    private let isNew: Bool

    init(event: PostOpEvent?, onSave: @escaping (String, String?, Date, String) -> Void) {
        self.onSave = onSave
        self.isNew = event == nil
        let initialCategory = event?.category ?? ReferenceData.eventCategories[0].name
        _category = State(initialValue: initialCategory)
        _subcategory = State(initialValue: event?.subcategory ?? ReferenceData.subcategories(for: initialCategory).first ?? "")
        _dateNoted = State(initialValue: event?.dateNoted ?? .now)
        _note = State(initialValue: event?.note ?? "")
    }

    private var subcategories: [String] {
        ReferenceData.subcategories(for: category)
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Category", selection: $category) {
                    ForEach(ReferenceData.eventCategories) { Text($0.name).tag($0.name) }
                }
                if !subcategories.isEmpty {
                    Picker("Subcategory", selection: $subcategory) {
                        ForEach(subcategories, id: \.self) { Text($0).tag($0) }
                    }
                }
                DatePicker("Date noted", selection: $dateNoted, displayedComponents: .date)
                TextField("Note", text: $note, axis: .vertical)
                    .lineLimit(1...4)
            }
            .onChange(of: category) { _, newCategory in
                subcategory = ReferenceData.subcategories(for: newCategory).first ?? ""
            }
            .navigationTitle(isNew ? "Add post-op event" : "Edit post-op event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(category, subcategories.isEmpty ? nil : subcategory, dateNoted, note)
                        dismiss()
                    }
                }
            }
        }
    }
}

import SwiftUI

/// A date of birth typed as MM/DD/YYYY. Stays empty (nil) until a whole, valid date is typed,
/// so it can't be skipped or left on a default.
struct DateEntryField: View {
    let title: String
    @Binding var date: Date?
    @State private var text = ""
    @State private var didLoad = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            LabeledContent(title) {
                TextField("MM/DD/YYYY", text: $text)
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
            }
            if !text.isEmpty && date == nil {
                Text("Enter a full date, like 03/14/1958")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            if let date { text = DateOnly.format(date) }
        }
        .onChange(of: text) { _, newValue in
            let parsed = DateOnly.parse(newValue)
            if parsed != date { date = parsed }
        }
    }
}

/// A date that starts empty. Tapping the button fills in today, which can then be changed.
struct OptionalDateRow: View {
    let title: String
    @Binding var date: Date?
    var emptyText = "Required"
    var emptyIsError = true
    var setButtonTitle = "Set date"
    var earliest: Date? = nil
    var latest: Date? = nil
    var canClear = false

    var body: some View {
        if date == nil {
            HStack {
                Text(title)
                Spacer()
                Text(emptyText)
                    .foregroundStyle(emptyIsError ? Color.red : Color.secondary)
                Button(setButtonTitle) {
                    date = DateOnly.normalize(clamped(.now))
                }
                .buttonStyle(.borderless)
            }
        } else {
            HStack {
                DatePicker(title, selection: selection, in: range, displayedComponents: .date)
                if canClear {
                    Button {
                        date = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Clear \(title.lowercased())")
                }
            }
        }
    }

    private var selection: Binding<Date> {
        Binding(
            get: { date ?? .now },
            set: { date = DateOnly.normalize($0) }
        )
    }

    private var range: ClosedRange<Date> {
        let lower = earliest ?? .distantPast
        return lower...max(lower, latest ?? .distantFuture)
    }

    private func clamped(_ value: Date) -> Date {
        min(max(value, range.lowerBound), range.upperBound)
    }
}

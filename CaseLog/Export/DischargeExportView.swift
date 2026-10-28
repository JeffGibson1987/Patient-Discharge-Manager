import SwiftData
import SwiftUI
import UIKit

/// Pick a week, check the list, create the PDF, and share it into Outlook.
struct DischargeExportView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<SurgicalCase> { $0.deletedAt == nil && $0.dischargeDate != nil })
    private var discharged: [SurgicalCase]

    @State private var week = DischargeWeek.interval(containing: .now)
    @State private var export: ExportedFile?
    @State private var errorMessage: String?

    private var casesInWeek: [SurgicalCase] {
        DischargeWeek.cases(discharged, in: week)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Button { week = DischargeWeek.shifted(week, byWeeks: -1) } label: {
                            Image(systemName: "chevron.left")
                        }
                        .accessibilityLabel("Previous week")
                        Spacer()
                        Text(DischargeWeek.label(for: week))
                            .font(.headline)
                        Spacer()
                        Button { week = DischargeWeek.shifted(week, byWeeks: 1) } label: {
                            Image(systemName: "chevron.right")
                        }
                        .accessibilityLabel("Next week")
                    }
                    .buttonStyle(.borderless)
                } footer: {
                    Text("Weeks run Monday to Sunday, by discharge date.")
                }

                Section("\(casesInWeek.count) discharged") {
                    if casesInWeek.isEmpty {
                        Text("No discharges this week")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(casesInWeek) { caseItem in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(caseItem.displayName)
                            Text("DC \(caseItem.dischargeDate?.formatted(date: .abbreviated, time: .omitted) ?? "") · \(caseItem.dischargeDestination?.rawValue ?? "")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Weekly discharge list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Share PDF") { createPDF() }
                        .disabled(casesInWeek.isEmpty)
                }
            }
            // Swiping the share sheet away skips its completion handler, so clean up here too.
            .sheet(item: $export, onDismiss: ExportFiles.removeAll) { file in
                ShareSheet(url: file.url) { activity, completed in
                    finishShare(file, activity: activity, completed: completed)
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    private func createPDF() {
        let cases = casesInWeek
        let data = DischargeListPDF.render(cases: cases, week: week)
        do {
            let url = try ExportFiles.write(data, weekStart: week.start)
            export = ExportedFile(url: url, caseCount: cases.count)
            errorMessage = nil
        } catch {
            errorMessage = "Could not create the PDF: \(error.localizedDescription)"
        }
    }

    private func finishShare(_ file: ExportedFile, activity: UIActivity.ActivityType?, completed: Bool) {
        ExportFiles.remove(file.url)
        export = nil
        let destination = activity?.rawValue ?? "none"
        let detail = "Week of \(DischargeWeek.label(for: week)), \(file.caseCount) patients, to \(destination), \(completed ? "sent" : "cancelled")"
        AuditLog.record(.export, detail: detail, in: context)
    }
}

struct ExportedFile: Identifiable {
    let id = UUID()
    let url: URL
    let caseCount: Int
}

/// The iOS share sheet, without the built-in destinations that would put PHI
/// somewhere other than your corporate email (AirDrop, Messages, Apple Mail, clipboard, Photos, print).
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    let onComplete: (UIActivity.ActivityType?, Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.excludedActivityTypes = [
            .airDrop,
            .message,
            .mail,
            .print,
            .copyToPasteboard,
            .assignToContact,
            .saveToCameraRoll,
            .addToReadingList,
            .markupAsPDF,
            .openInIBooks,
            .postToFacebook,
            .postToTwitter,
            .postToWeibo,
            .postToTencentWeibo,
            .postToFlickr,
            .postToVimeo,
            .sharePlay,
            .collaborationInviteWithLink,
            .collaborationCopyLink,
        ]
        controller.completionWithItemsHandler = { activity, completed, _, _ in
            onComplete(activity, completed)
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

import Foundation
import SwiftData

/// A post-operative event (complication), using the STS-style categories from
/// the Tristar discharge spreadsheet.
@Model
final class PostOpEvent {
    @Attribute(.unique) var id: UUID
    var category: String
    var subcategory: String?
    var dateNoted: Date
    var note: String
    var surgicalCase: SurgicalCase?

    init(category: String, subcategory: String? = nil, dateNoted: Date = .now, note: String = "") {
        self.id = UUID()
        self.category = category
        self.subcategory = subcategory
        self.dateNoted = dateNoted
        self.note = note
    }

    /// "Pulmonary: Prolonged ventilation", or just the category when it has no subcategory.
    var summary: String {
        if let subcategory, !subcategory.isEmpty {
            return "\(category): \(subcategory)"
        }
        return category
    }
}

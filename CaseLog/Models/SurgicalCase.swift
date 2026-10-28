import Foundation
import SwiftData

/// One operation. Holds the patient's PHI (name, DOB, gender, dates), the procedures,
/// any post-op events, and the discharge.
@Model
final class SurgicalCase {
    @Attribute(.unique) var id: UUID

    // PHI: keep to the minimum the discharge list needs.
    var firstName: String
    var lastName: String
    var dateOfBirth: Date
    var genderRaw: String
    var surgeryDate: Date

    var surgeon: String
    var referringProvider: String
    var procedures: [String]

    @Relationship(deleteRule: .cascade, inverse: \PostOpEvent.surgicalCase)
    var events: [PostOpEvent] = []

    var dischargeDate: Date?
    var dischargeDestinationRaw: String?
    var dischargeNotes: String

    var createdAt: Date
    var updatedAt: Date
    /// Soft delete: the case is hidden, then purged after `SurgicalCase.undoWindow`.
    var deletedAt: Date?

    init(
        firstName: String = "",
        lastName: String = "",
        dateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -65, to: .now) ?? .now,
        gender: Gender = .male,
        surgeryDate: Date = .now,
        surgeon: String = "",
        referringProvider: String = "",
        procedures: [String] = []
    ) {
        self.id = UUID()
        self.firstName = firstName
        self.lastName = lastName
        self.dateOfBirth = dateOfBirth
        self.genderRaw = gender.rawValue
        self.surgeryDate = surgeryDate
        self.surgeon = surgeon
        self.referringProvider = referringProvider
        self.procedures = procedures
        self.dischargeNotes = ""
        self.createdAt = .now
        self.updatedAt = .now
    }

    static let undoWindow: TimeInterval = 30 * 24 * 60 * 60

    var gender: Gender {
        get { Gender(rawValue: genderRaw) ?? .male }
        set { genderRaw = newValue.rawValue }
    }

    var dischargeDestination: DischargeDestination? {
        get { dischargeDestinationRaw.flatMap(DischargeDestination.init(rawValue:)) }
        set { dischargeDestinationRaw = newValue?.rawValue }
    }

    var isDischarged: Bool { dischargeDate != nil }

    /// Age in whole years on the day of surgery.
    var ageAtSurgery: Int {
        SurgicalCase.age(birth: dateOfBirth, on: surgeryDate)
    }

    var displayName: String {
        "\(lastName), \(firstName)"
    }

    var sortedEvents: [PostOpEvent] {
        events.sorted { $0.dateNoted < $1.dateNoted }
    }

    static func age(birth: Date, on date: Date, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.year], from: birth, to: date).year ?? 0
    }
}

enum Gender: String, CaseIterable, Identifiable, Codable {
    case male = "Male"
    case female = "Female"
    var id: String { rawValue }
}

enum DischargeDestination: String, CaseIterable, Identifiable, Codable {
    case home = "Home"
    case snf = "SNF"
    case rehab = "Rehab"
    case other = "Other"
    var id: String { rawValue }
}

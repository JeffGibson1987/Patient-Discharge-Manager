import Foundation
import SwiftData

/// One operation. Holds the patient's PHI (name, DOB, gender, dates), the procedures,
/// any post-op events, and the discharge.
///
/// Nothing that goes on the discharge list has a default value. A field that hasn't been
/// entered stays empty (nil), so a forgotten field shows as missing instead of looking right.
@Model
final class SurgicalCase {
    @Attribute(.unique) var id: UUID

    // PHI: keep to the minimum the discharge list needs.
    var firstName: String
    var lastName: String
    var dateOfBirth: Date?
    /// A `Gender` code ("male", "female"); nil until chosen.
    var genderRaw: String?
    var surgeryDate: Date?

    var surgeon: String
    var referringProvider: String
    var procedures: [String]

    @Relationship(deleteRule: .cascade, inverse: \PostOpEvent.surgicalCase)
    var events: [PostOpEvent] = []
    /// True when the surgeon has confirmed there were no post-op events.
    /// A complete record has either this or at least one event.
    var noPostOpEvents: Bool = false

    var dischargeDate: Date?
    /// A `DischargeDestination` code; nil until chosen.
    var dischargeDestinationRaw: String?
    var dischargeNotes: String

    var createdAt: Date
    var updatedAt: Date
    /// Soft delete: the case is hidden, then purged after `SurgicalCase.undoWindow`.
    var deletedAt: Date?

    init(
        firstName: String = "",
        lastName: String = "",
        dateOfBirth: Date? = nil,
        gender: Gender? = nil,
        surgeryDate: Date? = nil,
        surgeon: String = "",
        referringProvider: String = "",
        procedures: [String] = []
    ) {
        self.id = UUID()
        self.firstName = firstName
        self.lastName = lastName
        self.dateOfBirth = dateOfBirth
        self.genderRaw = gender?.rawValue
        self.surgeryDate = surgeryDate
        self.surgeon = surgeon
        self.referringProvider = referringProvider
        self.procedures = procedures
        self.noPostOpEvents = false
        self.dischargeNotes = ""
        self.createdAt = .now
        self.updatedAt = .now
    }

    static let undoWindow: TimeInterval = 30 * 24 * 60 * 60

    var gender: Gender? {
        get { genderRaw.flatMap(Gender.init(rawValue:)) }
        set { genderRaw = newValue?.rawValue }
    }

    var dischargeDestination: DischargeDestination? {
        get { dischargeDestinationRaw.flatMap(DischargeDestination.init(rawValue:)) }
        set { dischargeDestinationRaw = newValue?.rawValue }
    }

    var isDischarged: Bool { dischargeDate != nil }

    /// Age in whole years on the day of surgery, once both dates are entered.
    var ageAtSurgery: Int? {
        guard let dateOfBirth, let surgeryDate else { return nil }
        return SurgicalCase.age(birth: dateOfBirth, on: surgeryDate)
    }

    var displayName: String {
        "\(lastName), \(firstName)"
    }

    var sortedEvents: [PostOpEvent] {
        events.sorted { $0.dateNoted < $1.dateNoted }
    }

    // MARK: Required fields

    /// Fields a case must have before it can be saved at all.
    var missingRequiredFields: [String] {
        var missing: [String] = []
        if firstName.trimmingCharacters(in: .whitespaces).isEmpty { missing.append("First name") }
        if lastName.trimmingCharacters(in: .whitespaces).isEmpty { missing.append("Last name") }
        if dateOfBirth == nil { missing.append("Date of birth") }
        if gender == nil { missing.append("Gender") }
        if surgeryDate == nil { missing.append("Surgery date") }
        if procedures.isEmpty { missing.append("Procedures") }
        return missing
    }

    /// Everything still needed before the case can go on the weekly discharge list.
    var missingForDischargeList: [String] {
        var missing = missingRequiredFields
        if events.isEmpty && !noPostOpEvents { missing.append("Post-op events (or None)") }
        if dischargeDate == nil { missing.append("Discharge date") }
        if dischargeDestination == nil { missing.append("Discharge destination") }
        return missing
    }

    /// A complete record: every required field, post-op events answered, and discharged.
    /// Only complete records go on the discharge list.
    var isComplete: Bool { missingForDischargeList.isEmpty }

    static func age(birth: Date, on date: Date, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.year], from: birth, to: date).year ?? 0
    }
}

// Stored values are short codes that never change. The label is what the app shows,
// so a label can be reworded later without touching saved cases.
// New options can be added at any time; never rename or remove a code.

enum Gender: String, CaseIterable, Identifiable, Codable {
    case male
    case female

    var id: String { rawValue }

    var label: String {
        switch self {
        case .male: "Male"
        case .female: "Female"
        }
    }
}

/// In the order shown in the picker, most common first.
enum DischargeDestination: String, CaseIterable, Identifiable, Codable {
    case home
    case snf
    case rehab
    case ltac
    case hospice
    case anotherInstitution = "another_institution"
    case deceased

    var id: String { rawValue }

    var label: String {
        switch self {
        case .home: "Home"
        case .snf: "SNF"
        case .rehab: "Rehab"
        case .ltac: "LTAC"
        case .hospice: "Hospice"
        case .anotherInstitution: "Another institution"
        case .deceased: "Deceased"
        }
    }
}

/// Calendar dates (no time of day). Stored at noon so that a date never shifts
/// to the day before or after when the phone changes time zone.
enum DateOnly {
    static func normalize(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "M/d/yyyy"
        formatter.isLenient = false
        return formatter
    }()

    static func format(_ date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%02d/%02d/%04d", components.month ?? 0, components.day ?? 0, components.year ?? 0)
    }

    /// Reads a typed date such as "03/14/1958" or "3/14/1958". A two-digit year, an
    /// impossible date, a future date, or a year before 1900 gives nil.
    static func parse(_ text: String, now: Date = .now) -> Date? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.range(of: #"^\d{1,2}/\d{1,2}/\d{4}$"#, options: .regularExpression) != nil,
              let date = formatter.date(from: trimmed)
        else { return nil }
        let year = Calendar.current.component(.year, from: date)
        guard year >= 1900, date <= now else { return nil }
        return normalize(date)
    }
}

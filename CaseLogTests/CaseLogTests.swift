import SwiftData
import XCTest
@testable import CaseLog

@MainActor
final class CaseLogTests: XCTestCase {
    private var container: ModelContainer!

    override func setUp() async throws {
        container = try ModelContainer(
            for: SecureStore.schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    /// Model objects are inserted into an in-memory store, as they would be in the app.
    private func insert(_ caseItem: SurgicalCase) -> SurgicalCase {
        container.mainContext.insert(caseItem)
        return caseItem
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        DischargeWeek.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    /// A case with every field the discharge list needs.
    private func completeCase(_ lastName: String, surgery: Date, discharge: Date) -> SurgicalCase {
        let caseItem = insert(SurgicalCase(
            firstName: "Test",
            lastName: lastName,
            dateOfBirth: date(1960, 1, 1),
            gender: .male,
            surgeryDate: surgery,
            procedures: ["CABG"]
        ))
        caseItem.noPostOpEvents = true
        caseItem.dischargeDate = discharge
        caseItem.dischargeDestination = .home
        return caseItem
    }

    func testAgeIsWholeYearsOnSurgeryDay() {
        XCTAssertEqual(SurgicalCase.age(birth: date(1960, 10, 28), on: date(2026, 10, 27)), 65)
        XCTAssertEqual(SurgicalCase.age(birth: date(1960, 10, 28), on: date(2026, 10, 28)), 66)
    }

    func testNewCaseHasNoDefaultsForRequiredFields() {
        let caseItem = insert(SurgicalCase())
        XCTAssertNil(caseItem.gender)
        XCTAssertNil(caseItem.dateOfBirth)
        XCTAssertNil(caseItem.surgeryDate)
        XCTAssertNil(caseItem.ageAtSurgery)
        XCTAssertEqual(
            caseItem.missingRequiredFields,
            ["First name", "Last name", "Date of birth", "Gender", "Surgery date", "Procedures"]
        )
        XCTAssertFalse(caseItem.isComplete)
    }

    func testPostOpEventsMustBeNoneOrListed() {
        let caseItem = completeCase("Events", surgery: date(2026, 10, 20), discharge: date(2026, 10, 27))
        XCTAssertTrue(caseItem.isComplete)

        caseItem.noPostOpEvents = false
        XCTAssertFalse(caseItem.isComplete)
        XCTAssertEqual(caseItem.missingForDischargeList, ["Post-op events (or None)"])

        let event = PostOpEvent(category: "Atrial fibrillation")
        container.mainContext.insert(event)
        event.surgicalCase = caseItem
        XCTAssertTrue(caseItem.isComplete)
    }

    func testDischargeDestinationsInPickerOrder() {
        XCTAssertEqual(
            DischargeDestination.allCases.map(\.label),
            ["Home", "SNF", "Rehab", "LTAC", "Hospice", "Another institution", "Deceased"]
        )
    }

    func testTypedDateOfBirth() {
        let now = date(2026, 11, 15)
        XCTAssertNotNil(DateOnly.parse("03/14/1958", now: now))
        XCTAssertNotNil(DateOnly.parse("3/4/1958", now: now))
        XCTAssertNil(DateOnly.parse("3/14/58", now: now))
        XCTAssertNil(DateOnly.parse("13/01/1958", now: now))
        XCTAssertNil(DateOnly.parse("02/30/1958", now: now))
        XCTAssertNil(DateOnly.parse("01/01/2030", now: now))
        XCTAssertNil(DateOnly.parse("", now: now))
        XCTAssertEqual(DateOnly.format(DateOnly.parse("03/14/1958", now: now)!), "03/14/1958")
    }

    func testWeekRunsMondayToSunday() {
        let week = DischargeWeek.interval(containing: date(2026, 10, 28)) // a Wednesday
        let calendar = DischargeWeek.calendar
        XCTAssertEqual(calendar.component(.weekday, from: week.start), 2) // Monday
        XCTAssertEqual(calendar.component(.day, from: week.start), 26)
        XCTAssertEqual(calendar.component(.day, from: week.end), 2) // next Monday, Nov 2
    }

    func testWeekIncludesOnlyCompleteDischargedCasesInRange() {
        let inWeek = completeCase("Inweek", surgery: date(2026, 10, 20), discharge: date(2026, 11, 1))
        let nextWeek = completeCase("Nextweek", surgery: date(2026, 10, 25), discharge: date(2026, 11, 2))
        let stillInHospital = completeCase("Inpatient", surgery: date(2026, 10, 27), discharge: date(2026, 10, 28))
        stillInHospital.dischargeDate = nil
        let deleted = completeCase("Deleted", surgery: date(2026, 10, 20), discharge: date(2026, 10, 27))
        deleted.deletedAt = .now
        let noDestination = completeCase("Nodestination", surgery: date(2026, 10, 20), discharge: date(2026, 10, 28))
        noDestination.dischargeDestination = nil
        let eventsUnanswered = completeCase("Unanswered", surgery: date(2026, 10, 20), discharge: date(2026, 10, 28))
        eventsUnanswered.noPostOpEvents = false

        let all = [inWeek, nextWeek, stillInHospital, deleted, noDestination, eventsUnanswered]
        let week = DischargeWeek.interval(containing: date(2026, 10, 28))
        XCTAssertEqual(DischargeWeek.cases(all, in: week).map(\.lastName), ["Inweek"])
        XCTAssertEqual(
            Set(DischargeWeek.incompleteCases(all, in: week).map(\.lastName)),
            ["Nodestination", "Unanswered"]
        )
    }

    func testPDFRowsMatchColumns() {
        let caseItem = insert(SurgicalCase(
            firstName: "Jane",
            lastName: "Doe",
            dateOfBirth: date(1958, 3, 14),
            gender: .female,
            surgeryDate: date(2026, 1, 12),
            referringProvider: "Dr. Example",
            procedures: ["AV replacement", "CABG"]
        ))
        caseItem.noPostOpEvents = true
        caseItem.dischargeDate = date(2026, 1, 16)
        caseItem.dischargeDestination = .anotherInstitution
        caseItem.dischargeNotes = "Sample discharge note"

        let rows = DischargeListPDF.rows(for: [caseItem])
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].count, DischargeListPDF.columns.count)
        XCTAssertEqual(rows[0][0], "Doe, Jane")
        XCTAssertEqual(rows[0][1], "03/14/1958")
        XCTAssertEqual(rows[0][2], "67")
        XCTAssertEqual(rows[0][3], "Female")
        XCTAssertEqual(rows[0][6], "Another institution")
        XCTAssertEqual(rows[0][8], "AV replacement\nCABG")
        XCTAssertEqual(rows[0][9], "None")
    }

    func testPDFRendersAndColumnsFitPage() {
        XCTAssertEqual(DischargeListPDF.columns.reduce(0) { $0 + $1.width }, 720)
        let week = DischargeWeek.interval(containing: date(2026, 10, 28))
        let data = DischargeListPDF.render(cases: [], week: week)
        XCTAssertEqual(String(decoding: data.prefix(4), as: UTF8.self), "%PDF")
    }
}

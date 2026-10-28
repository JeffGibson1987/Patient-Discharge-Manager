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

    func testAgeIsWholeYearsOnSurgeryDay() {
        XCTAssertEqual(SurgicalCase.age(birth: date(1960, 10, 28), on: date(2026, 10, 27)), 65)
        XCTAssertEqual(SurgicalCase.age(birth: date(1960, 10, 28), on: date(2026, 10, 28)), 66)
    }

    func testWeekRunsMondayToSunday() {
        let week = DischargeWeek.interval(containing: date(2026, 10, 28)) // a Wednesday
        let calendar = DischargeWeek.calendar
        XCTAssertEqual(calendar.component(.weekday, from: week.start), 2) // Monday
        XCTAssertEqual(calendar.component(.day, from: week.start), 26)
        XCTAssertEqual(calendar.component(.day, from: week.end), 2) // next Monday, Nov 2
    }

    func testWeekIncludesOnlyDischargedCasesInRange() {
        let inWeek = insert(SurgicalCase(firstName: "A", lastName: "Inweek", surgeryDate: date(2026, 10, 20)))
        inWeek.dischargeDate = date(2026, 11, 1)
        let nextWeek = insert(SurgicalCase(firstName: "B", lastName: "Nextweek", surgeryDate: date(2026, 10, 25)))
        nextWeek.dischargeDate = date(2026, 11, 2)
        let stillInHospital = insert(SurgicalCase(firstName: "C", lastName: "Inpatient", surgeryDate: date(2026, 10, 27)))
        let deleted = insert(SurgicalCase(firstName: "D", lastName: "Deleted", surgeryDate: date(2026, 10, 20)))
        deleted.dischargeDate = date(2026, 10, 27)
        deleted.deletedAt = .now

        let week = DischargeWeek.interval(containing: date(2026, 10, 28))
        let result = DischargeWeek.cases([inWeek, nextWeek, stillInHospital, deleted], in: week)
        XCTAssertEqual(result.map(\.lastName), ["Inweek"])
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
        caseItem.dischargeDate = date(2026, 1, 16)
        caseItem.dischargeDestination = .home
        caseItem.dischargeNotes = "Sample discharge note"

        let rows = DischargeListPDF.rows(for: [caseItem])
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].count, DischargeListPDF.columns.count)
        XCTAssertEqual(rows[0][0], "Doe, Jane")
        XCTAssertEqual(rows[0][1], "03/14/1958")
        XCTAssertEqual(rows[0][2], "67")
        XCTAssertEqual(rows[0][6], "Home")
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

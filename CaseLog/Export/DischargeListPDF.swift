import UIKit

/// Renders the weekly discharge list as a landscape US Letter PDF with the
/// columns of the "Discharge List" sheet in the Tristar spreadsheet.
enum DischargeListPDF {
    struct Column {
        let title: String
        let width: CGFloat
    }

    // Widths add up to the 720 pt printable width (792 pt page, 36 pt margins).
    static let columns: [Column] = [
        Column(title: "Patient", width: 95),
        Column(title: "DOB", width: 55),
        Column(title: "Age", width: 28),
        Column(title: "Gender", width: 40),
        Column(title: "OR date", width: 55),
        Column(title: "DC date", width: 55),
        Column(title: "DC destination", width: 45),
        Column(title: "Referring provider", width: 75),
        Column(title: "Procedures", width: 100),
        Column(title: "Post-op events", width: 107),
        Column(title: "Notes", width: 65),
    ]

    private static let pageRect = CGRect(x: 0, y: 0, width: 792, height: 612)
    private static let margin: CGFloat = 36
    private static let padding: CGFloat = 3
    private static let bodyFont = UIFont.systemFont(ofSize: 8)
    private static let headerFont = UIFont.boldSystemFont(ofSize: 8)

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter
    }()

    /// One array of cell strings per case, in column order.
    static func rows(for cases: [SurgicalCase]) -> [[String]] {
        cases.map { caseItem in
            let events = caseItem.sortedEvents.map { event -> String in
                var line = "\(event.summary) (\(dateFormatter.string(from: event.dateNoted)))"
                if !event.note.isEmpty {
                    line += "; \(event.note)"
                }
                return line
            }
            return [
                caseItem.displayName,
                dateFormatter.string(from: caseItem.dateOfBirth),
                "\(caseItem.ageAtSurgery)",
                caseItem.gender.rawValue,
                dateFormatter.string(from: caseItem.surgeryDate),
                caseItem.dischargeDate.map { dateFormatter.string(from: $0) } ?? "",
                caseItem.dischargeDestination?.rawValue ?? "",
                caseItem.referringProvider,
                caseItem.procedures.joined(separator: "\n"),
                events.isEmpty ? "None" : events.joined(separator: "\n"),
                caseItem.dischargeNotes,
            ]
        }
    }

    static func render(cases: [SurgicalCase], week: DateInterval, generatedAt: Date = .now) -> Data {
        let rows = rows(for: cases)
        let format = UIGraphicsPDFRendererFormat()
        // Document metadata stays free of PHI.
        format.documentInfo = [
            kCGPDFContextTitle as String: "Discharge list",
            kCGPDFContextCreator as String: "Case Log",
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        return renderer.pdfData { context in
            var pageNumber = 0
            var y: CGFloat = 0
            let bottom = pageRect.height - margin - 14

            func startPage() {
                context.beginPage()
                pageNumber += 1
                y = margin
                if pageNumber == 1 {
                    draw("Cardiac surgery discharge list, week of \(DischargeWeek.label(for: week))",
                         in: CGRect(x: margin, y: y, width: 720, height: 20),
                         font: .boldSystemFont(ofSize: 14))
                    y += 20
                    let generated = generatedAt.formatted(date: .abbreviated, time: .shortened)
                    draw("\(cases.count) patient\(cases.count == 1 ? "" : "s") · generated \(generated) · Confidential: contains protected health information",
                         in: CGRect(x: margin, y: y, width: 720, height: 14),
                         font: .systemFont(ofSize: 9), color: .darkGray)
                    y += 22
                }
                y = drawHeaderRow(at: y)
                draw("Page \(pageNumber)",
                     in: CGRect(x: margin, y: pageRect.height - margin, width: 720, height: 12),
                     font: .systemFont(ofSize: 8), color: .darkGray, alignment: .right)
            }

            startPage()
            if rows.isEmpty {
                draw("No discharges this week.", in: CGRect(x: margin, y: y + padding, width: 720, height: 14), font: bodyFont)
                return
            }
            for row in rows {
                let height = rowHeight(row)
                if y + height > bottom {
                    startPage()
                }
                drawRow(row, at: y, height: height)
                y += height
            }
        }
    }

    // MARK: Drawing helpers

    private static func rowHeight(_ row: [String]) -> CGFloat {
        let tallest = zip(row, columns).map { text, column in
            textHeight(text, width: column.width - 2 * padding, font: bodyFont)
        }.max() ?? 0
        return max(tallest, bodyFont.lineHeight) + 2 * padding
    }

    private static func drawHeaderRow(at y: CGFloat) -> CGFloat {
        let height = columns.map { textHeight($0.title, width: $0.width - 2 * padding, font: headerFont) }.max() ?? 0
        let rowRect = CGRect(x: margin, y: y, width: 720, height: height + 2 * padding)
        UIColor(white: 0.9, alpha: 1).setFill()
        UIRectFill(rowRect)
        var x = margin
        for column in columns {
            draw(column.title,
                 in: CGRect(x: x + padding, y: y + padding, width: column.width - 2 * padding, height: height),
                 font: headerFont)
            x += column.width
        }
        return y + rowRect.height
    }

    private static func drawRow(_ row: [String], at y: CGFloat, height: CGFloat) {
        var x = margin
        for (text, column) in zip(row, columns) {
            draw(text,
                 in: CGRect(x: x + padding, y: y + padding, width: column.width - 2 * padding, height: height - 2 * padding),
                 font: bodyFont)
            x += column.width
        }
        let line = UIBezierPath()
        line.move(to: CGPoint(x: margin, y: y + height))
        line.addLine(to: CGPoint(x: margin + 720, y: y + height))
        line.lineWidth = 0.5
        UIColor.lightGray.setStroke()
        line.stroke()
    }

    private static func textHeight(_ text: String, width: CGFloat, font: UIFont) -> CGFloat {
        guard !text.isEmpty else { return 0 }
        let bounds = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            attributes: [.font: font],
            context: nil
        )
        return bounds.height.rounded(.up)
    }

    private static func draw(_ text: String, in rect: CGRect, font: UIFont, color: UIColor = .black, alignment: NSTextAlignment = .left) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.alignment = alignment
        (text as NSString).draw(
            with: rect,
            options: [.usesLineFragmentOrigin],
            attributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph],
            context: nil
        )
    }
}

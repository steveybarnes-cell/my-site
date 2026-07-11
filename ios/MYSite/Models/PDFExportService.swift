import Foundation
import UIKit

/// Renders a branded weekly report / payment-run PDF for My Project Group Ltd.
/// Fed by the same `DashboardAnalytics` rollups the on-screen dashboard uses,
/// so the exported document always matches what the admin/site manager sees.
enum PDFExportService {

  /// A4 portrait at 72dpi.
  private static let pageSize = CGSize(width: 595, height: 842)
  private static let margin: CGFloat = 40

  /// Renders the report and writes it to a temp file, returning the URL so it
  /// can be handed to a `ShareLink` / share sheet.
  static func exportDashboardReport(analytics: DashboardAnalytics, filter: DashboardFilter) -> URL?
  {
    let data = renderData(analytics: analytics, filter: filter)
    let name = "MPG-Report-\(Self.fileStamp()).pdf"
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
    do {
      try data.write(to: url, options: Data.WritingOptions.atomic)
      return url
    } catch {
      return nil
    }
  }

  // MARK: - Rendering

  private static func renderData(analytics: DashboardAnalytics, filter: DashboardFilter) -> Data {
    let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
    return renderer.pdfData { ctx in
      var cursor = Cursor(ctx: ctx, pageSize: pageSize, margin: margin)
      cursor.beginPage()

      drawHeader(&cursor, filter: filter)
      drawWeekSummary(&cursor, analytics.weekSummary)
      drawSiteCosts(&cursor, analytics.siteCosts)
      drawPaymentRun(&cursor, analytics.paymentRun)
      drawFooter(&cursor)
    }
  }

  private static func drawHeader(_ c: inout Cursor, filter: DashboardFilter) {
    let brand = UIColor(red: 0x63 / 255, green: 0xB8 / 255, blue: 0x77 / 255, alpha: 1)
    let ink = UIColor(red: 0x23 / 255, green: 0x27 / 255, blue: 0x1F / 255, alpha: 1)

    // Brand band
    let band = CGRect(x: 0, y: 0, width: pageSize.width, height: 84)
    UIColor(red: 0x2A / 255, green: 0x2E / 255, blue: 0x2B / 255, alpha: 1).setFill()
    UIRectFill(band)

    c.drawText(
      "MY PROJECT GROUP LTD", x: margin, y: 22,
      font: .systemFont(ofSize: 20, weight: .heavy), color: .white)
    c.drawText(
      "Site Record & Payment Report", x: margin, y: 50,
      font: .systemFont(ofSize: 12, weight: .medium), color: brand)

    let scope = filter.weekEnding.map { "Week ending \(longDate($0))" } ?? "All weeks"
    let generated = "Generated \(longDate(Date()))"
    c.drawText(
      scope, x: margin, y: 100,
      font: .systemFont(ofSize: 11, weight: .semibold), color: ink)
    c.drawText(
      generated, x: margin, y: 116,
      font: .systemFont(ofSize: 10, weight: .regular),
      color: UIColor(red: 0x5F / 255, green: 0x67 / 255, blue: 0x5A / 255, alpha: 1))
    c.y = 148
  }

  private static func drawWeekSummary(_ c: inout Cursor, _ s: WeekSummary) {
    c.sectionTitle("This Week Summary")
    let rows: [(String, String)] = [
      ("Total hours", Fmt.hours(s.totalHours)),
      ("Labour value", Fmt.gbp(s.labourValue)),
      ("Materials value", Fmt.gbp(s.materialsValue)),
      ("CIS deduction", Fmt.gbp(s.cisDeduction)),
      ("Net amount due", Fmt.gbp(s.netDue)),
      ("Invoices submitted", "\(s.invoicesSubmitted)"),
      ("Pending approval", "\(s.pendingApproval)"),
      ("Approved for payment", "\(s.approved)"),
      ("Paid", "\(s.paid)"),
      ("Queried", "\(s.queried)"),
    ]
    for (label, value) in rows {
      c.keyValue(label, value)
    }
    c.y += 8
  }

  private static func drawSiteCosts(_ c: inout Cursor, _ rows: [SiteCostRow]) {
    c.sectionTitle("Site Cost Summary")
    if rows.isEmpty {
      c.drawBody("No site costs for this selection.")
      c.y += 8
      return
    }
    c.tableHeader(["Site", "Labour", "Materials", "Total"], widths: [0.4, 0.2, 0.2, 0.2])
    for r in rows {
      c.tableRow(
        [r.siteName, Fmt.gbp(r.labour), Fmt.gbp(r.materials), Fmt.gbp(r.total)],
        widths: [0.4, 0.2, 0.2, 0.2])
    }
    c.y += 8
  }

  private static func drawPaymentRun(_ c: inout Cursor, _ rows: [PaymentRunRow]) {
    c.sectionTitle("Payment Run")
    if rows.isEmpty {
      c.drawBody("No invoices for this selection.")
      return
    }
    c.tableHeader(
      ["Contractor", "Invoice", "Net due", "Status"], widths: [0.34, 0.26, 0.2, 0.2])
    for r in rows {
      c.tableRow(
        [r.contractor, r.invoiceNumber, Fmt.gbp(r.netDue), r.paymentStatus],
        widths: [0.34, 0.26, 0.2, 0.2])
    }
    let totalNet = rows.reduce(0.0) { $0 + $1.netDue }
    c.y += 4
    c.keyValue("Total net due", Fmt.gbp(totalNet), bold: true)
  }

  private static func drawFooter(_ c: inout Cursor) {
    let footY = pageSize.height - 30
    c.drawText(
      "My Project Group Ltd — Confidential company report", x: margin, y: footY,
      font: .systemFont(ofSize: 8, weight: .regular),
      color: UIColor(red: 0x5F / 255, green: 0x67 / 255, blue: 0x5A / 255, alpha: 1))
  }

  // MARK: - Helpers

  private static func longDate(_ d: Date) -> String {
    d.formatted(.dateTime.day().month(.wide).year())
  }

  private static func fileStamp() -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd-HHmm"
    return f.string(from: Date())
  }
}

// MARK: - Layout cursor

/// Tracks the drawing position, paginates automatically, and draws the shared
/// text/table primitives used across report sections.
private struct Cursor {
  let ctx: UIGraphicsPDFRendererContext
  let pageSize: CGSize
  let margin: CGFloat
  var y: CGFloat = 0

  private var contentWidth: CGFloat { pageSize.width - margin * 2 }
  private let ink = UIColor(red: 0x23 / 255, green: 0x27 / 255, blue: 0x1F / 255, alpha: 1)
  private let soft = UIColor(red: 0x5F / 255, green: 0x67 / 255, blue: 0x5A / 255, alpha: 1)
  private let olive = UIColor(red: 0x5A / 255, green: 0x77 / 255, blue: 0x48 / 255, alpha: 1)
  private let hair = UIColor(red: 0xDB / 255, green: 0xE3 / 255, blue: 0xD5 / 255, alpha: 1)

  mutating func beginPage() {
    ctx.beginPage()
    y = margin
  }

  mutating func ensureSpace(_ needed: CGFloat) {
    if y + needed > pageSize.height - 40 {
      beginPage()
    }
  }

  mutating func sectionTitle(_ text: String) {
    ensureSpace(40)
    y += 6
    drawText(
      text, x: margin, y: y, font: .systemFont(ofSize: 14, weight: .bold), color: ink)
    y += 20
    olive.setFill()
    UIRectFill(CGRect(x: margin, y: y, width: contentWidth, height: 1.5))
    y += 8
  }

  mutating func keyValue(_ label: String, _ value: String, bold: Bool = false) {
    ensureSpace(20)
    let font: UIFont = bold ? .systemFont(ofSize: 11, weight: .bold) : .systemFont(ofSize: 11)
    drawText(label, x: margin, y: y, font: font, color: bold ? ink : soft)
    drawText(
      value, x: margin, y: y, font: font, color: ink,
      width: contentWidth, align: .right)
    y += 18
  }

  mutating func drawBody(_ text: String) {
    ensureSpace(20)
    drawText(text, x: margin, y: y, font: .systemFont(ofSize: 11), color: soft)
    y += 18
  }

  mutating func tableHeader(_ cells: [String], widths: [CGFloat]) {
    ensureSpace(24)
    hair.setFill()
    UIRectFill(CGRect(x: margin, y: y - 2, width: contentWidth, height: 18))
    drawCells(
      cells, widths: widths, font: .systemFont(ofSize: 10, weight: .bold), color: ink)
    y += 20
  }

  mutating func tableRow(_ cells: [String], widths: [CGFloat]) {
    ensureSpace(20)
    drawCells(cells, widths: widths, font: .systemFont(ofSize: 10), color: ink)
    y += 16
    hair.setFill()
    UIRectFill(CGRect(x: margin, y: y - 2, width: contentWidth, height: 0.5))
  }

  private func drawCells(_ cells: [String], widths: [CGFloat], font: UIFont, color: UIColor) {
    var x = margin
    for (i, cell) in cells.enumerated() {
      let w = contentWidth * (i < widths.count ? widths[i] : 0)
      let align: NSTextAlignment = i == 0 ? .left : .right
      drawText(cell, x: x, y: y, font: font, color: color, width: w, align: align)
      x += w
    }
  }

  func drawText(
    _ text: String, x: CGFloat, y: CGFloat, font: UIFont, color: UIColor,
    width: CGFloat? = nil, align: NSTextAlignment = .left
  ) {
    let para = NSMutableParagraphStyle()
    para.alignment = align
    para.lineBreakMode = .byTruncatingTail
    let attrs: [NSAttributedString.Key: Any] = [
      .font: font, .foregroundColor: color, .paragraphStyle: para,
    ]
    let drawWidth = width ?? (pageSize.width - x - margin)
    text.draw(
      with: CGRect(x: x, y: y, width: drawWidth, height: font.lineHeight + 2),
      options: [.usesLineFragmentOrigin], attributes: attrs, context: nil)
  }
}

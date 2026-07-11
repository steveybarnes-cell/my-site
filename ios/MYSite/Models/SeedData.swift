import CoreLocation
import Foundation

extension AppStore {
  func seed() {
    let cal = Calendar.current
    func daysAgo(_ n: Int) -> Date { cal.date(byAdding: .day, value: -n, to: Date())! }
    func daysAhead(_ n: Int) -> Date { cal.date(byAdding: .day, value: n, to: Date())! }

    // Users
    let steve = AppUser(
      id: UUID(), name: "Steve Marsh", email: "steve@myprojectgroup.co.uk", role: .admin,
      phone: "07700 900112", active: true)
    let jenny = AppUser(
      id: UUID(), name: "Jenny Cole", email: "jenny@myprojectgroup.co.uk", role: .siteManager,
      phone: "07700 900233", active: true)
    let paulSM = AppUser(
      id: UUID(), name: "Paul Hendry", email: "paul@myprojectgroup.co.uk", role: .siteManager,
      phone: "07700 900244", active: true)

    let brandon = AppUser(
      id: UUID(), name: "Brandon Reeves", email: "brandon@trade.com", role: .tradesman,
      phone: "07700 900301", active: true)
    let mike = AppUser(
      id: UUID(), name: "Mike Dolan", email: "mike@trade.com", role: .tradesman,
      phone: "07700 900302", active: true)
    let dan = AppUser(
      id: UUID(), name: "Dan Whitlock", email: "dan@trade.com", role: .tradesman,
      phone: "07700 900303", active: true)

    users = [steve, jenny, paulSM, brandon, mike, dan]

    // Profiles
    profiles = [
      TradesmanProfile(
        id: UUID(), userId: brandon.id, company: "Reeves Decorating Ltd",
        address: "14 Kingsdown Parade, Bristol BS6 5UD", utr: "1234567890", niNumber: "AB123456C",
        cisStatus: "Registered (20%)", mainTrade: "Painter & Decorator", vehicleReg: "BD68 KLM",
        bankName: "B Reeves", sortCode: "20-45-11", accountNumber: "•••• 4471", hourlyRate: 22,
        dayRate: 175, vatRegistered: false, vatNumber: "", notes: "Reliable, provides own tools.",
        bankChangePending: false),
      TradesmanProfile(
        id: UUID(), userId: mike.id, company: "Dolan Plumbing",
        address: "3 Elm Court, Clifton BS8 2AA", utr: "2233445566", niNumber: "CD654321B",
        cisStatus: "Registered (20%)", mainTrade: "Plumber", vehicleReg: "WK19 TRV",
        bankName: "M Dolan", sortCode: "09-01-27", accountNumber: "•••• 8820", hourlyRate: 28,
        dayRate: 220, vatRegistered: true, vatNumber: "GB998877665", notes: "Gas Safe registered.",
        bankChangePending: true),
      TradesmanProfile(
        id: UUID(), userId: dan.id, company: "Whitlock Groundworks",
        address: "88 Fishponds Rd, Bristol BS5 6SA", utr: "5566778899", niNumber: "EF112233A",
        cisStatus: "Registered (20%)", mainTrade: "Groundworker", vehicleReg: "YE20 GRW",
        bankName: "D Whitlock", sortCode: "40-22-09", accountNumber: "•••• 1290", hourlyRate: 24,
        dayRate: 190, vatRegistered: false, vatNumber: "", notes: "", bankChangePending: false),
    ]

    // Sites
    let marlborough = Site(
      id: UUID(), name: "Marlborough Street", address: "42 Marlborough St, Bristol BS1 3NT",
      client: "Bristol City Developments", siteManagerId: jenny.id, status: .active,
      notes: "Occupied building — mind residents.", whatsappLink: "wa.me/marlborough",
      defaultStart: "08:00", defaultFinish: "16:30",
      latitude: 51.4562, longitude: -2.5901, geofenceRadius: 150)
    let clifton = Site(
      id: UUID(), name: "Clifton Village", address: "7 The Mall, Clifton BS8 4DP",
      client: "Harbour Living", siteManagerId: paulSM.id, status: .active,
      notes: "Parking is limited, use rear access.", whatsappLink: "wa.me/clifton",
      defaultStart: "08:00", defaultFinish: "17:00",
      latitude: 51.4550, longitude: -2.6199, geofenceRadius: 120)
    let redcliffe = Site(
      id: UUID(), name: "Redcliffe Wharf", address: "12 Redcliffe Way, Bristol BS1 6NL",
      client: "Waterside Homes", siteManagerId: jenny.id, status: .paused,
      notes: "On hold pending drawings.", whatsappLink: "", defaultStart: "07:30",
      defaultFinish: "16:00", latitude: 51.4478, longitude: -2.5875, geofenceRadius: 150)
    sites = [marlborough, clifton, redcliffe]

    // Allocations
    allocations = [
      WorkAllocation(
        id: UUID(), siteId: marlborough.id, tradesmanId: brandon.id, siteManagerId: jenny.id,
        date: daysAhead(1), startTime: "08:00", expectedFinish: "16:30", trade: "Decorator",
        taskDescription: "Decorating snagging rooms 1–3. Before and after photos required.",
        category: .snagging, priority: .high, requiredPhotos: true,
        requiredMaterials: "Trade white emulsion, filler, sandpaper",
        notes: "Please submit your hours before leaving site.", status: .allocated),
      WorkAllocation(
        id: UUID(), siteId: clifton.id, tradesmanId: mike.id, siteManagerId: paulSM.id,
        date: Date(), startTime: "08:00", expectedFinish: "17:00", trade: "Plumber",
        taskDescription: "Plumbing first fix to flats 2 and 3.", category: .contract,
        priority: .normal, requiredPhotos: true, requiredMaterials: "15mm & 22mm copper, fittings",
        notes: "", status: .started),
      WorkAllocation(
        id: UUID(), siteId: clifton.id, tradesmanId: dan.id, siteManagerId: paulSM.id, date: Date(),
        startTime: "08:00", expectedFinish: "16:00", trade: "Groundworker",
        taskDescription: "Dig out floor in rear utility — variation to contract.",
        category: .variation, priority: .urgent, requiredPhotos: true,
        requiredMaterials: "Type 1, membrane", notes: "Instructed by client on site.",
        status: .accepted),
      WorkAllocation(
        id: UUID(), siteId: marlborough.id, tradesmanId: brandon.id, siteManagerId: jenny.id,
        date: daysAgo(3), startTime: "08:00", expectedFinish: "16:30", trade: "Decorator",
        taskDescription: "Second coat to communal hallway.", category: .contract, priority: .normal,
        requiredPhotos: false, requiredMaterials: "", notes: "", status: .completed),
    ]

    // Daily records
    dailyRecords = [
      DailyRecord(
        id: UUID(), allocationId: allocations[3].id, userId: brandon.id, siteId: marlborough.id,
        date: daysAgo(3), startTime: "08:00", finishTime: "16:30", breakMinutes: 30, totalHours: 8,
        trade: "Decorator",
        description: "Second coat emulsion to communal hallway and stairwell. Cut in and rolled.",
        category: .contract, delayReason: .none, delayNote: "", notes: "",
        variationInstructedBy: "", variationStatus: nil),
      DailyRecord(
        id: UUID(), allocationId: nil, userId: mike.id, siteId: clifton.id, date: daysAgo(2),
        startTime: "08:00", finishTime: "17:00", breakMinutes: 45, totalHours: 8.25,
        trade: "Plumber", description: "First fix flat 2 — hot and cold runs, waste.",
        category: .contract, delayReason: .materials,
        delayNote: "Waited 1hr for fittings delivery.", notes: "", variationInstructedBy: "",
        variationStatus: nil),
      DailyRecord(
        id: UUID(), allocationId: allocations[2].id, userId: dan.id, siteId: clifton.id,
        date: daysAgo(1), startTime: "08:00", finishTime: "16:00", breakMinutes: 30,
        totalHours: 7.5, trade: "Groundworker",
        description: "Dug out rear utility floor to 300mm, barrowed out spoil.",
        category: .variation, delayReason: .none, delayNote: "",
        notes: "Extra works — not in original contract.",
        variationInstructedBy: "Client (Mr Harding) on site", variationStatus: .awaiting),
    ]

    // Materials
    materials = [
      MaterialItem(
        id: UUID(), userId: brandon.id, siteId: marlborough.id, dailyRecordId: dailyRecords[0].id,
        date: daysAgo(3), supplier: "Screwfix", description: "Trade white emulsion 10L x2, filler",
        reason: "Snagging touch-ups", costExVat: 68.40, vatAmount: 13.68, receiptUploaded: true,
        chargeable: .no, approved: true, notes: ""),
      MaterialItem(
        id: UUID(), userId: mike.id, siteId: clifton.id, dailyRecordId: dailyRecords[1].id,
        date: daysAgo(2), supplier: "Plumb Center",
        description: "15mm copper x10, elbows, tee fittings", reason: "First fix flat 2",
        costExVat: 142.10, vatAmount: 28.42, receiptUploaded: true, chargeable: .yes,
        approved: false, notes: ""),
      MaterialItem(
        id: UUID(), userId: dan.id, siteId: clifton.id, dailyRecordId: dailyRecords[2].id,
        date: daysAgo(1), supplier: "Travis Perkins", description: "Type 1 MOT x1 tonne",
        reason: "Utility sub-base", costExVat: 54.00, vatAmount: 10.80, receiptUploaded: false,
        chargeable: .tbc, approved: false, notes: "Cash purchase — receipt to follow."),
    ]

    // Photos
    photos = [
      SitePhoto(
        id: UUID(), userId: brandon.id, siteId: marlborough.id, allocationId: allocations[3].id,
        type: .before, description: "Hallway before second coat", symbol: "photo",
        timestamp: daysAgo(3)),
      SitePhoto(
        id: UUID(), userId: brandon.id, siteId: marlborough.id, allocationId: allocations[3].id,
        type: .completed, description: "Hallway completed", symbol: "photo.fill",
        timestamp: daysAgo(3)),
      SitePhoto(
        id: UUID(), userId: dan.id, siteId: clifton.id, allocationId: allocations[2].id,
        type: .variation, description: "Excavation for variation works",
        symbol: "photo.badge.checkmark", timestamp: daysAgo(1)),
    ]

    // Weekly submissions
    let weekEnd = daysAgo(cal.component(.weekday, from: Date()) == 1 ? 0 : 5)
    submissions = [
      WeeklySubmission(
        id: UUID(), userId: brandon.id, weekEnding: daysAgo(7), invoiceNumber: "MPG-BR-0042",
        totalHours: 38, labourRate: 22, materialsTotal: 82.08, plantMileage: 20, cisRate: 0.20,
        vatRegistered: false, status: .paid, submittedAt: daysAgo(6), approvedBy: "Steve Marsh",
        paidDate: daysAgo(2)),
      WeeklySubmission(
        id: UUID(), userId: mike.id, weekEnding: daysAgo(7), invoiceNumber: "MPG-MD-0031",
        totalHours: 41, labourRate: 28, materialsTotal: 170.52, plantMileage: 35, cisRate: 0.20,
        vatRegistered: true, status: .queryRaised, submittedAt: daysAgo(5), approvedBy: nil,
        paidDate: nil),
      WeeklySubmission(
        id: UUID(), userId: dan.id, weekEnding: weekEnd, invoiceNumber: "MPG-DW-0019",
        totalHours: 36, labourRate: 24, materialsTotal: 64.80, plantMileage: 0, cisRate: 0.20,
        vatRegistered: false, status: .submitted, submittedAt: Date(), approvedBy: nil,
        paidDate: nil),
      WeeklySubmission(
        id: UUID(), userId: brandon.id, weekEnding: weekEnd, invoiceNumber: "MPG-BR-0043",
        totalHours: 16, labourRate: 22, materialsTotal: 0, plantMileage: 0, cisRate: 0.20,
        vatRegistered: false, status: .draft, submittedAt: nil, approvedBy: nil, paidDate: nil),
    ]

    // Comments
    comments = [
      QueryComment(
        id: UUID(), submissionId: submissions[1].id, fromName: "Steve Marsh", toUserId: mike.id,
        message: "Monday hours unclear. Please explain what was done between 12pm and 4pm.",
        timestamp: daysAgo(4), fromAdmin: true)
    ]

    // Notifications
    notifications = [
      AppNotification(
        id: UUID(), userId: brandon.id, type: "Allocation",
        message:
          "You have been allocated to Marlborough Street tomorrow at 08:00. Take before and after photos.",
        read: false, timestamp: daysAgo(0), symbol: "mappin.and.ellipse"),
      AppNotification(
        id: UUID(), userId: brandon.id, type: "Invoice",
        message: "Your invoice MPG-BR-0042 has been paid.", read: true, timestamp: daysAgo(2),
        symbol: "checkmark.seal.fill"),
      AppNotification(
        id: UUID(), userId: mike.id, type: "Query", message: "Steve has queried your Monday hours.",
        read: false, timestamp: daysAgo(4), symbol: "questionmark.bubble"),
      AppNotification(
        id: UUID(), userId: mike.id, type: "Receipt",
        message: "Receipt missing for a materials purchase — this cost may not be reimbursed.",
        read: false, timestamp: daysAgo(1), symbol: "exclamationmark.triangle.fill"),
      AppNotification(
        id: UUID(), userId: dan.id, type: "Photos",
        message: "Photos required for variation work at Clifton Village.", read: false,
        timestamp: daysAgo(1), symbol: "camera.fill"),
    ]

    // Clock in / attendance records (event-based GPS)
    func fix(_ lat: Double, _ lng: Double, _ acc: Double, site: Site) -> LocationFix {
      LocationFix.compute(
        coord: CLLocationCoordinate2D(latitude: lat, longitude: lng), accuracy: acc, site: site)
    }
    func at(_ day: Int, _ h: Int, _ m: Int) -> Date {
      cal.date(bySettingHour: h, minute: m, second: 0, of: daysAgo(day)) ?? daysAgo(day)
    }

    clockRecords = [
      ClockRecord(
        id: UUID(), userId: mike.id, tradesmanName: mike.name, siteId: clifton.id,
        siteName: clifton.name, date: Date(), device: "Mobile device",
        clockInTime: at(0, 8, 2), clockInFix: fix(51.4551, -2.6198, 9, site: clifton),
        clockInStatus: .valid),
      ClockRecord(
        id: UUID(), userId: dan.id, tradesmanName: dan.name, siteId: clifton.id,
        siteName: clifton.name, date: Date(), device: "Mobile device",
        clockInTime: at(0, 8, 41), clockInFix: fix(51.4610, -2.6300, 14, site: clifton),
        clockInStatus: .outsideSite,
        reasonNote: "Parked in overflow car park across the main road, radius too tight."),
      ClockRecord(
        id: UUID(), userId: brandon.id, tradesmanName: brandon.name, siteId: marlborough.id,
        siteName: marlborough.name, date: daysAgo(1), device: "Mobile device",
        clockInTime: at(1, 7, 58), clockInFix: fix(51.4562, -2.5901, 8, site: marlborough),
        clockInStatus: .valid,
        clockOutTime: at(1, 16, 34), clockOutFix: fix(51.4563, -2.5900, 10, site: marlborough),
        clockOutStatus: .valid, claimedHours: 8),
    ]

    // Site files
    func file(
      _ site: Site, _ title: String, _ cat: FileCategory, _ origin: FileOrigin,
      _ type: String, by: AppUser, days: Int, notes: String = "",
      url: String = "", vis: FileVisibility = .everyone, approval: FileApproval = .awaiting,
      tags: [String] = [], handover: Bool = false, tradesman: AppUser? = nil
    ) -> SiteFile {
      let week = FileStorage.weekEndingSunday(for: daysAgo(days))
      let folder =
        [
          FileStorage.rootFolder, "Site Files", site.name, cat.rawValue,
          "WE " + week.formatted(.dateTime.day().month(.twoDigits).year()),
        ].joined(separator: " / ")
      return SiteFile(
        id: UUID(), siteId: site.id, title: title, category: cat, origin: origin,
        fileType: type, uploadedById: by.id, uploadedByName: by.name, uploadedAt: daysAgo(days),
        tradesmanId: tradesman?.id, notes: notes,
        driveURL: url.isEmpty
          ? "https://drive.google.com/file/d/drv_\(UUID().uuidString.prefix(16))/view" : url,
        driveFolderPath: folder, visibility: vis, approval: approval, tags: tags,
        inHandoverPack: handover)
    }

    siteFiles = [
      file(
        marlborough, "Ground Floor Plan Rev C", .drawings, .driveLink, "Drive link",
        by: steve, days: 12, notes: "Latest issued architect drawing.", approval: .approved,
        tags: ["rev-c", "architect"]),
      file(
        marlborough, "Structural Calcs — Steel Beam", .structural, .upload, "PDF",
        by: jenny, days: 11, approval: .approved, tags: ["steel", "engineer"], handover: true),
      file(
        marlborough, "RAMS — Decorating Works", .rams, .upload, "PDF",
        by: jenny, days: 9, notes: "Signed by contractor.", approval: .approved, handover: true),
      file(
        marlborough, "Screwfix Receipt — Emulsion", .materialsReceipt, .upload, "JPG",
        by: brandon, days: 3, notes: "Trade white x4, filler.", approval: .awaiting,
        tags: ["screwfix"], tradesman: brandon),
      file(
        marlborough, "Snagging — Room 2 Before", .beforePhotos, .upload, "JPG",
        by: brandon, days: 2, approval: .approved, tradesman: brandon),
      file(
        marlborough, "Building Control Completion", .buildingControl, .upload, "PDF",
        by: steve, days: 1, approval: .approved, handover: true),
      file(
        clifton, "Client Instruction — Kitchen Change", .clientInstruction, .driveLink,
        "Drive link", by: paulSM, days: 6, notes: "Email export from client.", approval: .approved),
      file(
        clifton, "Variation — Extra Radiator", .variationEvidence, .upload, "JPG",
        by: mike, days: 4, notes: "Photo of installed radiator.", approval: .awaiting,
        tags: ["variation"], tradesman: mike),
      file(
        clifton, "Travis Perkins Invoice", .supplierInvoice, .upload, "PDF",
        by: mike, days: 4, approval: .awaiting, tradesman: mike),
      file(
        clifton, "Electrical Certificate", .warranty, .upload, "PDF",
        by: steve, days: 2, approval: .approved, handover: true),
      file(
        redcliffe, "Programme v2", .programme, .driveLink, "Drive link",
        by: jenny, days: 8, approval: .approved),
    ]

    // Company feed (general posts + group chat)
    func minsAgo(_ n: Int) -> Date { cal.date(byAdding: .minute, value: -n, to: Date())! }
    func hrsAgo(_ n: Int) -> Date { cal.date(byAdding: .hour, value: -n, to: Date())! }

    feedPosts = [
      FeedPost(
        authorId: steve.id, authorName: steve.name, authorRole: .admin,
        text:
          "Morning all 👋 New standard invoice format is now live in the app — please submit weekly invoices through here from now on, no more WhatsApp photos. Any questions give me a shout.",
        photoSymbols: [], siteId: nil, timestamp: hrsAgo(26),
        likedBy: [jenny.id, brandon.id, mike.id, dan.id],
        comments: [
          FeedComment(
            authorId: brandon.id, authorName: brandon.name,
            text: "Nice one Steve, much easier than the old way.", timestamp: hrsAgo(25)),
          FeedComment(
            authorId: mike.id, authorName: mike.name,
            text: "Works well. Receipt scanner is spot on 👍", timestamp: hrsAgo(24)),
        ]),
      FeedPost(
        authorId: dan.id, authorName: dan.name, authorRole: .tradesman,
        text:
          "Rear utility dig-out done at Clifton Village. Ready for the sub-base tomorrow. Photos attached for the variation.",
        photoSymbols: ["digOut", "screed"], siteId: clifton.id, timestamp: hrsAgo(20),
        likedBy: [paulSM.id, steve.id],
        comments: [
          FeedComment(
            authorId: paulSM.id, authorName: paulSM.name,
            text: "Great work Dan, I'll get the variation signed off.", timestamp: hrsAgo(19))
        ]),
      FeedPost(
        authorId: jenny.id, authorName: jenny.name, authorRole: .siteManager,
        text:
          "Reminder: hard hats and hi-vis at all times on Marlborough Street — building control are visiting Thursday. Cheers.",
        photoSymbols: [], siteId: marlborough.id, timestamp: hrsAgo(6),
        likedBy: [steve.id, brandon.id],
        comments: []),
      FeedPost(
        authorId: brandon.id, authorName: brandon.name, authorRole: .tradesman,
        text: "Communal hallway second coat finished at Marlborough. Looking clean ✨",
        photoSymbols: ["hallwayPaint", "kitchenFit"], siteId: marlborough.id,
        timestamp: minsAgo(45),
        likedBy: [jenny.id, steve.id, mike.id],
        comments: [
          FeedComment(
            authorId: jenny.id, authorName: jenny.name, text: "Looks brilliant 👏",
            timestamp: minsAgo(30))
        ]),
      FeedPost(
        authorId: mike.id, authorName: mike.name, authorRole: .tradesman,
        text:
          "Brickwork to the rear extension up to DPC at Clifton. Blockwork inner leaf going in this afternoon. On programme.",
        photoSymbols: ["brickwork", "screed"], siteId: clifton.id, timestamp: hrsAgo(9),
        likedBy: [steve.id, paulSM.id, jenny.id],
        comments: [
          FeedComment(
            authorId: steve.id, authorName: steve.name,
            text: "Good progress Mike 👌 keep the photos coming for the handover file.",
            timestamp: hrsAgo(8)),
          FeedComment(
            authorId: paulSM.id, authorName: paulSM.name,
            text: "Sand & cement delivery booked for 7am tomorrow.", timestamp: hrsAgo(7)),
        ]),
      FeedPost(
        authorId: paulSM.id, authorName: paulSM.name, authorRole: .siteManager,
        text:
          "Scaffold inspection tag updated on Redcliffe — signed off and safe to use. Weekly check due next Friday.",
        photoSymbols: ["scaffold"], siteId: redcliffe.id, timestamp: hrsAgo(4),
        likedBy: [steve.id, mike.id, dan.id],
        comments: []),
      FeedPost(
        authorId: steve.id, authorName: steve.name, authorRole: .admin,
        text:
          "Reminder 📋 weekly invoices + timesheets in by Friday 5pm please so I can get everyone paid Monday. Receipts through the scanner as you go — don't let them pile up!",
        photoSymbols: [], siteId: nil, timestamp: hrsAgo(3),
        likedBy: [mike.id, dan.id, brandon.id, jenny.id, paulSM.id],
        comments: [
          FeedComment(
            authorId: dan.id, authorName: dan.name,
            text: "Mine's already in 👍", timestamp: hrsAgo(2))
        ]),
      FeedPost(
        authorId: brandon.id, authorName: brandon.name, authorRole: .tradesman,
        text:
          "New kitchen units landed at Marlborough — carcasses in, worktops templated. Should be finished by end of week.",
        photoSymbols: ["kitchenFit"], siteId: marlborough.id, timestamp: minsAgo(20),
        likedBy: [jenny.id, steve.id],
        comments: [
          FeedComment(
            authorId: jenny.id, authorName: jenny.name,
            text: "Client will be made up with that 🙌", timestamp: minsAgo(12))
        ]),
    ]
  }
}

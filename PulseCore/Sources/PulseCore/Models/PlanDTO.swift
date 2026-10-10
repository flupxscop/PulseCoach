import Foundation

// Codable plan types shared by iPhone, Watch and widgets.
// Kept free of FoundationModels so the watch and tests never link the LLM framework.

public enum ActivityKind: String, Codable, Sendable, CaseIterable {
    case rest, walk, run, cycle, strength, hiit, yoga

    public var displayName: String {
        switch self {
        case .rest: "วันพัก"
        case .walk: "เดินเบาๆ"
        case .run: "วิ่งเบาๆ"
        case .cycle: "ปั่นจักรยาน"
        case .strength: "เวทเทรนนิ่ง"
        case .hiit: "HIIT"
        case .yoga: "โยคะ"
        }
    }

    public var systemImage: String {
        switch self {
        case .rest: "bed.double.fill"
        case .walk: "figure.walk"
        case .run: "figure.run"
        case .cycle: "figure.outdoor.cycle"
        case .strength: "dumbbell.fill"
        case .hiit: "flame.fill"
        case .yoga: "figure.yoga"
        }
    }
}

public enum IntensityLevel: String, Codable, Sendable, CaseIterable, Comparable {
    case easy, moderate, hard

    public var displayName: String {
        switch self {
        case .easy: "เบา"
        case .moderate: "ปานกลาง"
        case .hard: "หนัก"
        }
    }

    /// Heart-rate zone used for WorkoutKit alerts.
    public var heartRateZone: Int {
        switch self {
        case .easy: 2
        case .moderate: 3
        case .hard: 4
        }
    }

    public var lower: IntensityLevel {
        switch self {
        case .hard: .moderate
        case .moderate, .easy: .easy
        }
    }

    private var rank: Int {
        switch self {
        case .easy: 0
        case .moderate: 1
        case .hard: 2
        }
    }

    public static func < (lhs: IntensityLevel, rhs: IntensityLevel) -> Bool { lhs.rank < rhs.rank }
}

public struct DayDTO: Codable, Sendable, Equatable, Identifiable {
    public var dayIndex: Int          // 1...7, day 1 = the day the plan was created
    public var activity: ActivityKind
    public var minutes: Int
    public var intensity: IntensityLevel
    public var tip: String

    public var id: Int { dayIndex }

    public init(dayIndex: Int, activity: ActivityKind, minutes: Int,
                intensity: IntensityLevel, tip: String) {
        self.dayIndex = dayIndex
        self.activity = activity
        self.minutes = minutes
        self.intensity = intensity
        self.tip = tip
    }

    public static func rest(dayIndex: Int) -> DayDTO {
        DayDTO(dayIndex: dayIndex, activity: .rest, minutes: 0, intensity: .easy,
               tip: "นอนให้ได้ 7 ชั่วโมงขึ้นไป ร่างกายแข็งแรงขึ้นตอนพัก")
    }

    public var isRest: Bool { activity == .rest }
}

public enum PlanSource: String, Codable, Sendable {
    case onDeviceModel, ruleBased
}

public struct PlanDTO: Codable, Sendable, Equatable {
    public var createdAt: Date
    public var rationale: String
    public var days: [DayDTO]
    public var source: PlanSource

    public init(createdAt: Date, rationale: String, days: [DayDTO], source: PlanSource) {
        self.createdAt = createdAt
        self.rationale = rationale
        self.days = days
        self.source = source
    }

    /// The day matching `date`, counting `createdAt` as day 1.
    public func day(for date: Date, calendar: Calendar = .current) -> DayDTO? {
        let start = calendar.startOfDay(for: createdAt)
        let target = calendar.startOfDay(for: date)
        guard let offset = calendar.dateComponents([.day], from: start, to: target).day else { return nil }
        return days.first { $0.dayIndex == offset + 1 }
    }
}

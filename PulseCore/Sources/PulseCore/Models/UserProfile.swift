import Foundation

public enum FitnessGoal: String, Codable, Sendable, CaseIterable, Identifiable {
    case getFitter, loseWeight, buildMuscle, reduceStress

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .getFitter: "ฟิตขึ้น"
        case .loseWeight: "ลดน้ำหนัก"
        case .buildMuscle: "เพิ่มกล้ามเนื้อ"
        case .reduceStress: "ลดความเครียด"
        }
    }

    public var subtitle: String {
        switch self {
        case .getFitter: "หัวใจแข็งแรง เหนื่อยช้าลง"
        case .loseWeight: "เผาผลาญมากขึ้นอย่างปลอดภัย"
        case .buildMuscle: "เน้นเวทเทรนนิ่ง"
        case .reduceStress: "โยคะ เดิน และพักให้พอ"
        }
    }

    public var systemImage: String {
        switch self {
        case .getFitter: "heart.circle.fill"
        case .loseWeight: "flame.circle.fill"
        case .buildMuscle: "dumbbell.fill"
        case .reduceStress: "leaf.circle.fill"
        }
    }

    /// English label used inside LLM prompts.
    public var promptName: String {
        switch self {
        case .getFitter: "improve cardio fitness"
        case .loseWeight: "lose weight safely"
        case .buildMuscle: "build muscle"
        case .reduceStress: "reduce stress"
        }
    }
}

public enum PreferredTime: String, Codable, Sendable, CaseIterable, Identifiable {
    case morning, evening, flexible

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .morning: "เช้า"
        case .evening: "เย็น"
        case .flexible: "ไม่แน่นอน"
        }
    }

    /// Hour used when scheduling workouts into the Workout app.
    public var scheduleHour: Int {
        switch self {
        case .morning: 7
        case .evening: 18
        case .flexible: 12
        }
    }
}

public enum FitnessLevel: String, Codable, Sendable, CaseIterable {
    case beginner, intermediate, advanced
}

public struct UserProfile: Codable, Sendable, Equatable {
    public var goal: FitnessGoal
    public var daysPerWeek: Int        // 3...7, active (non-rest) days
    public var preferredTime: PreferredTime
    public var level: FitnessLevel
    public var maxMinutes: Int

    public init(goal: FitnessGoal = .getFitter, daysPerWeek: Int = 5,
                preferredTime: PreferredTime = .morning,
                level: FitnessLevel = .beginner, maxMinutes: Int = 45) {
        self.goal = goal
        self.daysPerWeek = min(max(daysPerWeek, 3), 7)
        self.preferredTime = preferredTime
        self.level = level
        self.maxMinutes = maxMinutes
    }
}

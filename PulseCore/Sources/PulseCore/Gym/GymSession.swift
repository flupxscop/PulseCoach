import Foundation

/// One completed set, logged so the user can see and fix it ("แก้ไข") during rest.
public struct SetLog: Sendable, Codable, Equatable {
    public var exerciseID: String
    public var setNumber: Int
    public var reps: Int
    public var weightKg: Double?
}

/// Pure state machine for a guided gym session on the watch:
/// exercise → finish set → rest (countdown) → next set … → finished.
/// Time is passed in, so every transition is testable without a clock.
public struct GymSession: Sendable, Equatable {
    public enum Phase: Sendable, Equatable {
        case exercise
        case rest(endsAt: Date)
        case finished
    }

    public static let restRange: ClosedRange<TimeInterval> = 15...300

    public let exercises: [Exercise]
    public private(set) var exerciseIndex = 0
    public private(set) var setNumber = 1
    public private(set) var phase: Phase = .exercise
    public private(set) var logs: [SetLog] = []
    /// Reps counted for the current set (Digital Crown); 0 means "use the target".
    public var currentReps = 0
    public var restDuration: TimeInterval

    public init(exercises: [Exercise], restDuration: TimeInterval = 60) {
        self.exercises = exercises
        self.restDuration = restDuration
        if exercises.isEmpty { phase = .finished }
    }

    // MARK: Read

    public var current: Exercise? { exercises.indices.contains(exerciseIndex) ? exercises[exerciseIndex] : nil }

    /// Reps shown on screen: what the user counted, or the target before they start counting.
    public var displayReps: Int { currentReps }

    public var lastLog: SetLog? { logs.last }

    public var isResting: Bool {
        if case .rest = phase { return true }
        return false
    }

    public func restRemaining(at now: Date) -> TimeInterval {
        guard case .rest(let endsAt) = phase else { return 0 }
        return max(0, endsAt.timeIntervalSince(now))
    }

    /// Fraction of the rest left, for the amber tick ring.
    public func restProgress(at now: Date) -> Double {
        guard restDuration > 0 else { return 0 }
        return min(1, restRemaining(at: now) / restDuration)
    }

    // MARK: Transitions

    /// Logs the set and moves to rest. Unspecified reps count as the target.
    public mutating func finishSet(at now: Date) {
        guard case .exercise = phase, let ex = current else { return }
        let reps = currentReps > 0 ? currentReps : ex.reps
        logs.append(SetLog(exerciseID: ex.id, setNumber: setNumber, reps: reps, weightKg: ex.defaultWeightKg))
        currentReps = 0

        if setNumber < ex.sets {
            setNumber += 1
        } else {
            exerciseIndex += 1
            setNumber = 1
        }
        phase = current == nil ? .finished : .rest(endsAt: now.addingTimeInterval(restDuration))
    }

    /// Skips the rest of the current exercise without logging it.
    public mutating func skipExercise() {
        guard phase != .finished else { return }
        exerciseIndex += 1
        setNumber = 1
        currentReps = 0
        phase = current == nil ? .finished : .exercise
    }

    /// −15 / +15 during rest. Keeps the remaining time inside `restRange`.
    public mutating func adjustRest(by seconds: TimeInterval, now: Date) {
        guard case .rest(let endsAt) = phase else { return }
        let remaining = min(max(endsAt.timeIntervalSince(now) + seconds, 0), Self.restRange.upperBound)
        phase = .rest(endsAt: now.addingTimeInterval(remaining))
        if remaining > restDuration { restDuration = remaining }
    }

    /// "เริ่มเซ็ตต่อไป" — ends rest early or after the countdown.
    public mutating func startNextSet() {
        guard isResting else { return }
        phase = .exercise
        currentReps = 0
    }

    /// Fix the reps of the set just logged.
    public mutating func editLastSet(reps: Int) {
        guard !logs.isEmpty else { return }
        logs[logs.count - 1].reps = max(0, reps)
    }

    /// Digital Crown counting, clamped to 0...99.
    public mutating func setReps(_ reps: Int) {
        currentReps = min(max(reps, 0), 99)
    }
}

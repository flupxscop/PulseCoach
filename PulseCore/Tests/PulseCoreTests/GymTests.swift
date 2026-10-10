import Foundation
import Testing
@testable import PulseCore

private let t0 = Date(timeIntervalSince1970: 1_791_500_000)

@Test func libraryIsComplete() {
    #expect(ExerciseLibrary.all.count == 9)
    #expect(Set(ExerciseLibrary.all.map(\.id)).count == 9)
    #expect(ExerciseLibrary.all.allSatisfy { $0.steps.count == 3 && $0.sets > 0 && $0.reps > 0 })
    #expect(ExerciseLibrary.backDay.count == 6)
    #expect(ExerciseLibrary.barbellRow.startImage == "ex-row-1")
    #expect(ExerciseLibrary.dumbbellRow.dose == "3 เซ็ต × 10 ครั้ง/ข้าง")
    #expect(ExerciseLibrary.barbellRow.weightText == "40 กก.")
}

@Test func finishSetLogsAndRests() {
    var s = GymSession(exercises: ExerciseLibrary.backDay)
    s.setReps(8)
    s.finishSet(at: t0)
    #expect(s.logs == [SetLog(exerciseID: "row", setNumber: 1, reps: 8, weightKg: 40)])
    #expect(s.phase == .rest(endsAt: t0.addingTimeInterval(60)))
    #expect(s.setNumber == 2 && s.current?.id == "row")
    #expect(s.currentReps == 0)
}

@Test func uncountedSetUsesTarget() {
    var s = GymSession(exercises: [ExerciseLibrary.latPulldown])
    s.finishSet(at: t0)
    #expect(s.lastLog?.reps == 12)
}

@Test func lastSetMovesToNextExercise() {
    var s = GymSession(exercises: [ExerciseLibrary.barbellRow, ExerciseLibrary.latPulldown])
    for _ in 1...3 {
        s.finishSet(at: t0)
        s.startNextSet()
    }
    #expect(s.current?.id == "pulldown")
    #expect(s.setNumber == 1)
    #expect(s.logs.count == 3)
}

@Test func sessionFinishesAfterLastSet() {
    var s = GymSession(exercises: [ExerciseLibrary.barbellRow])
    for _ in 1...3 {
        s.finishSet(at: t0)
        s.startNextSet()
    }
    #expect(s.phase == .finished)
    #expect(s.current == nil)
}

@Test func restCountdownAndAdjust() {
    var s = GymSession(exercises: ExerciseLibrary.backDay, restDuration: 60)
    s.finishSet(at: t0)
    #expect(s.restRemaining(at: t0.addingTimeInterval(15)) == 45)
    #expect(s.restProgress(at: t0.addingTimeInterval(15)) == 0.75)

    s.adjustRest(by: 15, now: t0.addingTimeInterval(15))
    #expect(s.restRemaining(at: t0.addingTimeInterval(15)) == 60)

    s.adjustRest(by: -15, now: t0.addingTimeInterval(15))
    s.adjustRest(by: -60, now: t0.addingTimeInterval(15))
    #expect(s.restRemaining(at: t0.addingTimeInterval(15)) == 0)

    s.adjustRest(by: 1000, now: t0)
    #expect(s.restRemaining(at: t0) == GymSession.restRange.upperBound)
    #expect(s.restProgress(at: t0) == 1)
}

@Test func restIsNeverNegativeAfterTimeout() {
    var s = GymSession(exercises: ExerciseLibrary.backDay)
    s.finishSet(at: t0)
    #expect(s.restRemaining(at: t0.addingTimeInterval(500)) == 0)
}

@Test func skipExerciseDoesNotLog() {
    var s = GymSession(exercises: [ExerciseLibrary.barbellRow, ExerciseLibrary.latPulldown])
    s.skipExercise()
    #expect(s.logs.isEmpty)
    #expect(s.current?.id == "pulldown" && s.phase == .exercise)
    s.skipExercise()
    #expect(s.phase == .finished)
}

@Test func editLastSetFixesReps() {
    var s = GymSession(exercises: ExerciseLibrary.backDay)
    s.finishSet(at: t0)
    s.editLastSet(reps: 11)
    #expect(s.lastLog?.reps == 11)
    s.editLastSet(reps: -3)
    #expect(s.lastLog?.reps == 0)
}

@Test func crownRepsAreClamped() {
    var s = GymSession(exercises: ExerciseLibrary.backDay)
    s.setReps(150)
    #expect(s.currentReps == 99)
    s.setReps(-1)
    #expect(s.currentReps == 0)
}

@Test func emptySessionIsFinished() {
    #expect(GymSession(exercises: []).phase == .finished)
}

@Test func actionsIgnoredInWrongPhase() {
    var s = GymSession(exercises: ExerciseLibrary.backDay)
    s.startNextSet()                    // not resting
    s.adjustRest(by: 15, now: t0)       // not resting
    #expect(s.phase == .exercise)
    s.finishSet(at: t0)
    let resting = s
    s.finishSet(at: t0)                 // already resting
    #expect(s == resting)
}

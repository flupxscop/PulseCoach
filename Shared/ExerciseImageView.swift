import SwiftUI
import PulseCore

/// Alternates the start and end frames of a move (1.2 s each) so the user can follow the rhythm.
/// Shows the start frame only when Reduce Motion is on or `animated` is false (thumbnails).
struct ExerciseImageView: View {
    let exercise: Exercise
    var animated = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let interval = 1.2

    var body: some View {
        TimelineView(.periodic(from: .now, by: Self.interval)) { context in
            let showEnd = animated && !reduceMotion
                && Int(context.date.timeIntervalSinceReferenceDate / Self.interval) % 2 == 1
            ZStack {
                Image(exercise.startImage).resizable().scaledToFit().opacity(showEnd ? 0 : 1)
                Image(exercise.endImage).resizable().scaledToFit().opacity(showEnd ? 1 : 0)
            }
            .animation(.easeInOut(duration: 0.35), value: showEnd)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .accessibilityElement()
        .accessibilityLabel("ภาพสาธิตท่า \(exercise.name)")
    }
}

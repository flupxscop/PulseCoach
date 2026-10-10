import SwiftUI
import PulseCore

@main
struct PulseCoachWatchApp: App {
    @State private var health: HealthService
    @State private var store = PlanStore()
    @State private var workout: WorkoutManager

    init() {
        let health = HealthService()
        _health = State(initialValue: health)
        _workout = State(initialValue: WorkoutManager(store: health.store))
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                // One question per screen, paged with the Digital Crown.
                TabView {
                    WatchTodayView()
                    WatchWeekView()
                }
                .tabViewStyle(.verticalPage)
            }
            .environment(health)
            .environment(store)
            .environment(workout)
            .task {
                store.activate()
                try? await health.requestAuthorization()
            }
        }
    }
}

import SwiftUI
import PulseCore

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if model.hasOnboarded {
            MainTabView()
        } else {
            NavigationStack {
                WelcomeView()
            }
        }
    }
}

/// System TabView: on iOS 26+ it renders as the floating Liquid Glass tab bar automatically.
struct MainTabView: View {
    @Environment(AppModel.self) private var model
    @State private var showProfile = false

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.selectedTab) {
            Tab("วันนี้", systemImage: "circle.circle.fill", value: AppTab.today) {
                NavigationStack { TodayView().profileButton($showProfile) }
            }
            Tab("แผน", systemImage: "calendar", value: AppTab.plan) {
                NavigationStack { PlanView().profileButton($showProfile) }
            }
            Tab("ร่างกาย", systemImage: "chart.bar.fill", value: AppTab.body) {
                NavigationStack { BodyView().profileButton($showProfile) }
            }
        }
        .sheet(isPresented: $showProfile) {
            ProfileView()
        }
    }
}

private struct ProfileButton: ViewModifier {
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isPresented = true
                } label: {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                }
                .accessibilityLabel("โปรไฟล์และการตั้งค่า")
            }
        }
    }
}

extension View {
    func profileButton(_ isPresented: Binding<Bool>) -> some View {
        modifier(ProfileButton(isPresented: isPresented))
    }
}

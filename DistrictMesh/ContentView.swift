import SwiftUI

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// Owns the single mesh instance and gates between the onboarding journey and
/// the main app based on whether the user has completed setup.
struct RootView: View {
    @State private var mesh = MeshConnectivityManager()
    @AppStorage("district.onboarded") private var onboarded = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if onboarded {
                MeshTestView(mesh: mesh)
            } else {
                OnboardingView(mesh: mesh) { onboarded = true }
            }
        }
        .tint(DistrictTheme.accent)
        .preferredColorScheme(.dark)
        .animation(.easeInOut, value: onboarded)
        // Pick up any Siri/Shortcuts request when we come forward. Handled both
        // on appear (cold launch from Siri) and on becoming active (warm launch).
        .onAppear { mesh.consumePendingIntents() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { mesh.consumePendingIntents() }
        }
    }
}

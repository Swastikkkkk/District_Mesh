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
    }
}

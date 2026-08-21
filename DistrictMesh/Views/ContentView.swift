import SwiftUI

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    @State private var mesh = MeshConnectivityManager()
    @AppStorage("district.onboarded") private var onboarded = false
    @AppStorage("district.walkthroughDone") private var walkthroughDone = false
    @State private var showSplash = true

    var body: some View {
        ZStack {
            mainContent
            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .tint(DistrictTheme.accent)
        .preferredColorScheme(.dark)
        .fontDesign(.rounded)
        .animation(.easeInOut, value: onboarded)
        .animation(.easeInOut, value: walkthroughDone)
        .task {
            try? await Task.sleep(for: .seconds(2.0))
            withAnimation(.easeOut(duration: 0.5)) { showSplash = false }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if !onboarded {
            OnboardingView(mesh: mesh) { onboarded = true }
        } else if !walkthroughDone {
            WalkthroughView { walkthroughDone = true }
        } else {
            DashboardView(mesh: mesh)
                .onAppear {
                    if !mesh.isLive { mesh.startHosting(); mesh.startBrowsing() }
                }
        }
    }
}

struct SplashView: View {
    @State private var pulse = false
    @State private var appear = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.09, green: 0.05, blue: 0.22),
                         Color(red: 0.04, green: 0.03, blue: 0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                ZStack {
                    ForEach(0..<4, id: \.self) { i in
                        Circle()
                            .stroke(DistrictTheme.accent.opacity(0.18), lineWidth: 1)
                            .frame(
                                width: pulse ? CGFloat(112 + i * 52) : 24,
                                height: pulse ? CGFloat(112 + i * 52) : 24
                            )
                            .opacity(pulse ? 0 : 1)
                            .animation(
                                .easeOut(duration: 2.0)
                                    .repeatForever(autoreverses: false)
                                    .delay(Double(i) * 0.45),
                                value: pulse
                            )
                    }

                    ZStack {
                        Circle()
                            .fill(DistrictTheme.accent.opacity(0.18))
                            .frame(width: 106, height: 106)
                        Circle()
                            .stroke(DistrictTheme.accent.opacity(0.45), lineWidth: 1.5)
                            .frame(width: 106, height: 106)
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 46, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 290, height: 290)

                VStack(spacing: 10) {
                    Text("District Mesh")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Connect offline, together")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.45))
                        .tracking(0.4)
                }
            }
            .opacity(appear ? 1 : 0)
            .scaleEffect(appear ? 1 : 0.84)
            .onAppear {
                withAnimation(.spring(duration: 0.65)) { appear = true }
                withAnimation(.linear(duration: 0.01).delay(0.2)) { pulse = true }
            }
        }
    }
}

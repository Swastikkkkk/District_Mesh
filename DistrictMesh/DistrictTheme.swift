import SwiftUI

/// Lightweight brand styling for the District mesh screens. Centralised so the
/// look can be swapped to match District's existing palette in one place.
enum DistrictTheme {
    /// Primary brand accent.
    static let accent = Color(red: 0.45, green: 0.30, blue: 0.95)

    /// Emergency / panic colour.
    static let alert = Color(red: 0.95, green: 0.23, blue: 0.30)

    /// Secondary accent used in gradients.
    static let accentDeep = Color(red: 0.30, green: 0.20, blue: 0.85)

    /// Gradient used for headers and the panic button.
    static let brandGradient = LinearGradient(
        colors: [accent, accentDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Full-bleed dark gradient for immersive screens (onboarding / calls).
    static let immersiveGradient = LinearGradient(
        colors: [Color(red: 0.10, green: 0.07, blue: 0.22),
                 Color(red: 0.20, green: 0.12, blue: 0.42),
                 accent],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Calm dark gradient used behind content screens (Mesh / Chat / Map).
    static let screenGradient = LinearGradient(
        colors: [Color(red: 0.06, green: 0.05, blue: 0.13),
                 Color(red: 0.10, green: 0.07, blue: 0.20)],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Screen background (platform-appropriate grouped look).
    static var groupedBackground: Color {
        #if canImport(UIKit)
        Color(.systemGroupedBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }

    /// Subtle fill for chat bubbles from other people.
    static var bubbleBackground: Color {
        #if canImport(UIKit)
        Color(.secondarySystemBackground)
        #else
        Color(nsColor: .underPageBackgroundColor)
        #endif
    }
}

extension View {
    /// Dark, translucent "glass" card used consistently across every screen.
    func glassCard(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            )
    }

    /// Full-screen dark brand background behind a scrollable content screen.
    func districtBackground() -> some View {
        self.background(DistrictTheme.screenGradient.ignoresSafeArea())
    }
}

/// District logo lockup. Uses an "AppLogo" image asset if present in the
/// asset catalog; otherwise falls back to a styled wordmark so there's always a
/// clean brand mark. Drop the real logo into Assets as "AppLogo" to use it.
struct DistrictLogo: View {
    var size: CGFloat = 44
    var showsWordmark: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            mark
            if showsWordmark {
                Text("District")
                    .font(.system(size: size * 0.62, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
    }

    @ViewBuilder
    private var mark: some View {
        #if canImport(UIKit)
        if UIImage(named: "AppLogo") != nil {
            Image("AppLogo").resizable().scaledToFit()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.28))
        } else {
            wordmarkMark
        }
        #else
        wordmarkMark
        #endif
    }

    private var wordmarkMark: some View {
        RoundedRectangle(cornerRadius: size * 0.28)
            .fill(DistrictTheme.brandGradient)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundStyle(.white)
            )
    }
}

/// Full-width, prominent brand button used for primary actions.
struct DistrictButtonStyle: ButtonStyle {
    var tint: LinearGradient = DistrictTheme.brandGradient
    var foreground: Color = .white
    var disabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(tint, in: RoundedRectangle(cornerRadius: 16))
            .opacity(disabled ? 0.4 : (configuration.isPressed ? 0.85 : 1))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

import ActivityKit
import WidgetKit
import SwiftUI

// NOTE: `DistrictWidgetsAttributes` is defined in the app's
// `MeshActivityAttributes.swift`. That file must ALSO be a member of this
// widget extension target (File Inspector → Target Membership → tick
// "DistrictWidgets").

struct DistrictWidgetsLiveActivity: Widget {
    private let accent = Color(red: 0.45, green: 0.30, blue: 0.95)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DistrictWidgetsAttributes.self) { context in
            // Lock screen / banner
            HStack(spacing: 14) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.title2).foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("District Mesh").font(.headline)
                    Text(context.state.headline).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                countBadge(context.state.connectedCount)
            }
            .padding()
            .activityBackgroundTint(.black.opacity(0.55))
            .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.title2).foregroundStyle(accent)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countBadge(context.state.connectedCount)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text("District Mesh").font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.headline).font(.caption).foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "dot.radiowaves.left.and.right").foregroundStyle(accent)
            } compactTrailing: {
                Text("\(context.state.connectedCount)").font(.caption.bold())
            } minimal: {
                Image(systemName: "dot.radiowaves.left.and.right").foregroundStyle(accent)
            }
            .keylineTint(accent)
        }
    }

    private func countBadge(_ count: Int) -> some View {
        Text("\(count) on mesh")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(accent.opacity(0.25), in: Capsule())
    }
}

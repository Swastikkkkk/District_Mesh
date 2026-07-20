import ActivityKit
import WidgetKit
import SwiftUI

// NOTE: `DistrictWidgetsAttributes` is defined in the app's
// `MeshActivityAttributes.swift`. That file must ALSO be a member of this
// widget extension target (File Inspector → Target Membership → tick
// "DistrictWidgets").

struct DistrictWidgetsLiveActivity: Widget {
    // Vivid high-contrast colors so the pill is impossible to miss against the
    // black Dynamic Island / lock screen.
    private let accent = Color.green
    private let accent2 = Color(red: 0.0, green: 0.9, blue: 1.0) // bright cyan

    private func icon(_ state: DistrictWidgetsAttributes.ContentState) -> String {
        state.isSharingLocation ? "location.fill" : "dot.radiowaves.left.and.right"
    }
    private func title(_ state: DistrictWidgetsAttributes.ContentState) -> String {
        state.isSharingLocation ? "Sharing location" : "Live on mesh"
    }

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DistrictWidgetsAttributes.self) { context in
            // Lock screen / banner
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(accent).frame(width: 46, height: 46)
                    Image(systemName: icon(context.state))
                        .font(.title3.bold()).foregroundStyle(.black)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title(context.state)).font(.headline.bold()).foregroundStyle(accent)
                    Text(context.state.headline)
                        .font(.subheadline).foregroundStyle(.white)
                }
                Spacer()
                countBadge(context.state.connectedCount)
            }
            .padding()
            .activityBackgroundTint(.black)
            .activitySystemActionForegroundColor(accent)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.state.isSharingLocation ? "Location" : "Mesh")
                            .font(.caption.bold()).foregroundStyle(.white)
                    } icon: {
                        Image(systemName: icon(context.state)).foregroundStyle(accent)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countBadge(context.state.connectedCount)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(title(context.state))
                        .font(.caption.bold()).foregroundStyle(accent)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.headline)
                        .font(.headline.bold()).foregroundStyle(.white)
                }
            } compactLeading: {
                Image(systemName: icon(context.state))
                    .font(.body.bold())
                    .foregroundStyle(accent)
            } compactTrailing: {
                Text("\(context.state.connectedCount)")
                    .font(.body.bold())
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(accent, in: Capsule())
            } minimal: {
                Image(systemName: icon(context.state))
                    .font(.body.bold())
                    .foregroundStyle(accent)
            }
            .keylineTint(accent)
        }
    }

    private func countBadge(_ count: Int) -> some View {
        Label("\(count)", systemImage: "person.2.fill")
            .font(.subheadline.weight(.bold)).foregroundStyle(.black)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(accent, in: Capsule())
    }
}

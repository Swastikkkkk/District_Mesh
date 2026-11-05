import AppIntents
import SwiftUI
import WidgetKit

/// Control Center / Lock Screen / Action button: one tap starts SOS.
struct WidgetControl: ControlWidget {
    static let kind = "com.swastik.districtmesh.sos"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenURLIntent(URL(string: "districtmesh://sos")!)) {
                Label("Mesh SOS", systemImage: "location.fill")
            }
        }
        .displayName("Mesh SOS")
        .description("Opens District Mesh and shares your live location with your group.")
    }
}

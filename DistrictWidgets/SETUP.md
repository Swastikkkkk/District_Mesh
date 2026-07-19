# DistrictWidgets — setup (one-time, ~4 clicks)

The Live Activity (Dynamic Island) and home-screen widget need a **Widget
Extension target**, which can only be created in Xcode's UI. Everything else
(all the code) is already written.

## 1. Create the target
Xcode → **File ▸ New ▸ Target… ▸ Widget Extension** → Product Name: **DistrictWidgets**
→ ✅ check **Include Live Activity** → Finish → **Activate** the scheme if asked.

## 2. Replace the template files with these
Delete the sample files Xcode created inside the new `DistrictWidgets` group, then
drag in the three files from this folder:
- `DistrictWidgetsBundle.swift`
- `BuddyCompassLiveActivity.swift`
- `BuddyLocationWidget.swift`

## 3. Share the two app files with the widget target
Select each of these (in the app group), open the **File Inspector** (right panel),
and under **Target Membership** also tick **DistrictWidgets**:
- `BuddyCompassAttributes.swift`
- `SharedStore.swift`

## 4. (Optional) Home-screen location widget data — needs a paid team
The Live Activity / Dynamic Island works with **no extra setup**.
The home-screen *location* widget needs a shared App Group (paid Apple Developer
account required):
- Select the **DistrictMesh** target → Signing & Capabilities → **+ Capability ▸ App Groups**
  → add `group.com.swastik.districtmesh`.
- Do the same on the **DistrictWidgets** target.
- (On a free team, skip this — the Live Activity still works; the location widget
  just won't have data.)

## Done
Build & run. Open **Find a buddy** in the app → the compass Live Activity appears
in the Dynamic Island automatically (the app starts/updates it). Long-press the
home screen → add the **Crew Locations** widget.

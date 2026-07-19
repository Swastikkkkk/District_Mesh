//
//  DistrictWidgetsBundle.swift
//  DistrictWidgets
//
//  Created by Swastik on 19/07/26.
//

import WidgetKit
import SwiftUI

@main
struct DistrictWidgetsBundle: WidgetBundle {
    var body: some Widget {
        DistrictWidgets()
        DistrictWidgetsControl()
        DistrictWidgetsLiveActivity()
    }
}

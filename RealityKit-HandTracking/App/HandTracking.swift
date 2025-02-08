/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
The app's main entry point.
*/

import ARKit
import RealityKit
import SwiftUI

@main
struct HandTracking: App {
    @State private var rightHandEntity: Entity?

    var body: some SwiftUI.Scene {
        WindowGroup {
            MainView(rightHandEntity: $rightHandEntity)
        }

        ImmersiveSpace(id: "HandTrackingScene") {
            HandTrackingView(rightHandEntity: $rightHandEntity)
        }
    }
}

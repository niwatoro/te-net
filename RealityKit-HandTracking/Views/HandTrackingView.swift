/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
A structure with the entity view protocol to generate and update meshes for each hand anchor.
*/

import ARKit
import RealityKit
import SwiftUI

/// A reality view that contains all hand-tracking entities.
struct HandTrackingView: View {
    /// Binding to the right hand entity
    @Binding var rightHandEntity: Entity?

    /// The main body of the view.
    var body: some View {
        RealityView { content in
            makeHandEntities(in: content)
        }
    }

    /// Creates the entity that contains all hand-tracking entities.
    @MainActor
    func makeHandEntities(in content: any RealityViewContentProtocol) {
        // Add the right hand.
        let rightHand = Entity()
        rightHand.components.set(HandTrackingComponent(chirality: .right))
        content.add(rightHand)
        rightHandEntity = rightHand
        print("Set right hand entity")
    }
}

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
    /// References to hand tracking entities
    @Binding var rightHandEntity: Entity?
    @Binding var leftHandEntity: Entity?

    /// The main body of the view.
    var body: some View {
        RealityView { content in
            makeHandEntities(in: content)
        }
    }

    /// Creates the entity that contains all hand-tracking entities.
    @MainActor
    func makeHandEntities(in content: any RealityViewContentProtocol) {
        // Add the forward right hand
        let rightHand = Entity()
        rightHand.components.set(HandTrackingComponent(chirality: .right))
        content.add(rightHand)
        rightHandEntity = rightHand

        // Add the forward left hand
        let leftHand = Entity()
        leftHand.components.set(HandTrackingComponent(chirality: .left))
        content.add(leftHand)
        leftHandEntity = leftHand
    }
}

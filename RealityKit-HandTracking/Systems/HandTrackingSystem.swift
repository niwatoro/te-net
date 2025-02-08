/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
A system that updates entities that have hand-tracking components.
*/
import ARKit
import QuartzCore
import RealityKit

/// A system that provides hand-tracking capabilities.
struct HandTrackingSystem: System {
    /// The active ARKit session.
    static var arSession = ARKitSession()

    /// The provider instance for hand-tracking.
    static let handTracking = HandTrackingProvider()

    /// The most recent anchor that the provider detects on the right hand.
    static var latestRightHand: HandAnchor?

    /// Recording duration in seconds
    static let recordingDuration: TimeInterval = 10.0

    init(scene: RealityKit.Scene) {
        Task { await Self.runSession() }
    }

    @MainActor
    static func runSession() async {
        do {
            try await arSession.run([handTracking])
        } catch let error as ARKitSession.Error {
            print(
                "The app has encountered an error while running providers: \(error.localizedDescription)"
            )
        } catch let error {
            print("The app has encountered an unexpected error: \(error.localizedDescription)")
        }

        for await anchorUpdate in handTracking.anchorUpdates {
            switch anchorUpdate.anchor.chirality {
            case .right:
                self.latestRightHand = anchorUpdate.anchor
            default:
                break
            }
        }
    }

    /// The query this system uses to find all entities with the hand-tracking component.
    static let query = EntityQuery(where: .has(HandTrackingComponent.self))

    /// Performs any necessary updates to the entities with the hand-tracking component.
    /// - Parameter context: The context for the system to update.
    func update(context: SceneUpdateContext) {
        let handEntities = context.entities(matching: Self.query, updatingSystemWhen: .rendering)
        let currentTime = CACurrentMediaTime()

        for entity in handEntities {
            guard var handComponent = entity.components[HandTrackingComponent.self] else {
                continue
            }

            if handComponent.fingers.isEmpty {
                self.addJoints(to: entity, handComponent: &handComponent)
            }

            guard
                let handAnchor: HandAnchor =
                    switch handComponent.chirality {
                    case .right: Self.latestRightHand
                    default: nil
                    }
            else { continue }

            // Handle recording mode
            if handComponent.mode == .recording,
                let startTime = handComponent.recordingStartTime
            {
                let elapsedTime = currentTime - startTime

                if elapsedTime >= Self.recordingDuration {
                    handComponent.stop()
                } else if let handSkeleton = handAnchor.handSkeleton {
                    // Record current frame
                    var frameTransforms: [HandSkeleton.JointName: simd_float4x4] = [:]
                    for jointName in handComponent.fingers.keys {
                        frameTransforms[jointName] =
                        handAnchor.originFromAnchorTransform *   handSkeleton.joint(jointName).anchorFromJointTransform
                    }
                    let frame = HandFrame(jointTransforms: frameTransforms, timestamp: elapsedTime)
                    handComponent.recordedFrames.append(frame)
                }
            }

            // Handle playback mode
            if handComponent.mode == .playing,
                let startTime = handComponent.playbackStartTime,
                !handComponent.recordedFrames.isEmpty
            {
                let elapsedTime = currentTime - startTime

                if elapsedTime >= Self.recordingDuration {
                    handComponent.stop()
                } else {
                    // Find the closest recorded frame for the current time
                    let frame = handComponent.recordedFrames.min {
                        abs($0.timestamp - elapsedTime) < abs($1.timestamp - elapsedTime)
                    }

                    if let frame = frame {
                        // Apply recorded transforms to joints
                        for (jointName, jointEntity) in handComponent.fingers {
                            if let transform = frame.jointTransforms[jointName] {
                                jointEntity.setTransformMatrix(
                                    transform,
                                    relativeTo: nil
                                )
                            }
                        }
                    }
                }
            }

            // Handle idle mode (normal tracking)
            if handComponent.mode == .idle,
                let handSkeleton = handAnchor.handSkeleton
            {
                for (jointName, jointEntity) in handComponent.fingers {
                    let anchorFromJointTransform = handSkeleton.joint(jointName)
                        .anchorFromJointTransform
                    jointEntity.setTransformMatrix(
                        handAnchor.originFromAnchorTransform * anchorFromJointTransform,
                        relativeTo: nil
                    )
                }
            }

            // Update the component
            entity.components.set(handComponent)
        }
    }

    /// Performs any necessary setup to the entities with the hand-tracking component.
    /// - Parameters:
    ///   - entity: The entity to perform setup on.
    ///   - handComponent: The hand-tracking component to update.
    func addJoints(to handEntity: Entity, handComponent: inout HandTrackingComponent) {
        let radius: Float = 0.01
        let material = SimpleMaterial(color: .white, isMetallic: false)
        let sphereEntity = ModelEntity(
            mesh: .generateSphere(radius: radius),
            materials: [material]
        )

        for bone in Hand.joints {
            let newJoint = sphereEntity.clone(recursive: false)
            handEntity.addChild(newJoint)
            handComponent.fingers[bone.0] = newJoint
        }

        handEntity.components.set(handComponent)
    }
}

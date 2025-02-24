/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
A system that updates entities that have hand-tracking components.
*/
import ARKit.hand_skeleton
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

    /// The most recent anchor that the provider detects on the left hand.
    static var latestLeftHand: HandAnchor?

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
            case .left:
                self.latestLeftHand = anchorUpdate.anchor
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

            if handComponent.forwardFingers.isEmpty || handComponent.backwardFingers.isEmpty {
                self.addJoints(to: entity, handComponent: &handComponent)
            }

            guard
                let handAnchor: HandAnchor =
                    switch handComponent.chirality {
                    case .right: Self.latestRightHand
                    case .left: Self.latestLeftHand
                    default: nil
                    }
            else { continue }

            // Handle idle mode (normal tracking)
            if handComponent.mode == .idle {
                // Hide backward entities
                for (_, jointEntity) in handComponent.backwardFingers {
                    jointEntity.isEnabled = false
                }
            }

            // Handle recording
            if handComponent.mode == .playing,
                let handSkeleton = handAnchor.handSkeleton,
                let startTime = handComponent.recordingStartTime
            {
                let elapsedTime = currentTime - startTime

                if elapsedTime >= Self.recordingDuration {
                    handComponent.stop()
                } else {
                    // Record current frame
                    var frameTransforms: [HandSkeleton.JointName: simd_float4x4] = [:]
                    for jointName in handComponent.forwardFingers.keys {
                        frameTransforms[jointName] =
                            handAnchor.originFromAnchorTransform
                            * handSkeleton.joint(jointName).anchorFromJointTransform
                    }
                    let frame = HandFrame(jointTransforms: frameTransforms, timestamp: elapsedTime)
                    handComponent.recordedFrames.append(frame)
                }
            }

            // Handle playback
            if handComponent.mode == .playing,
                let startTime = handComponent.playbackStartTime,
                !handComponent.playingFrames.isEmpty
            {
                let elapsedTime = currentTime - startTime
                let reversedElapsedTime = Self.recordingDuration - elapsedTime

                if elapsedTime >= Self.recordingDuration {
                    handComponent.stop()
                } else {
                    // Find the closest recorded frame for the current time
                    let frame = handComponent.playingFrames.min {
                        abs($0.timestamp - reversedElapsedTime)
                            < abs($1.timestamp - reversedElapsedTime)
                    }

                    if let frame = frame {
                        // Show and update backward entities with recorded positions
                        for (jointName, jointEntity) in handComponent.backwardFingers {
                            jointEntity.isEnabled = true
                            if let transform = frame.jointTransforms[jointName] {
                                jointEntity.setTransformMatrix(transform, relativeTo: nil)
                            }
                        }
                    }
                }
            }

            // Check for collisions during playback
            if handComponent.mode == .playing {
                var isColliding = false
                // Compare each forward finger with each backward finger
                for (_, forwardJoint) in handComponent.forwardFingers {
                    for (_, backwardJoint) in handComponent.backwardFingers
                    where backwardJoint.isEnabled {
                        let distance = simd_distance(
                            forwardJoint.position,
                            backwardJoint.position
                        )
                        if distance < HandTrackingComponent.collisionThreshold {
                            isColliding = true
                            break
                        }
                    }
                    if isColliding { break }
                }

                // Update collision state
                if isColliding && !handComponent.isColliding {
                    handComponent.isColliding = true
                    handComponent.mode = .gameOver
                }

                // Check for marker collisions and manage markers
                if let handSkeleton = handAnchor.handSkeleton {
                    var jointPositions: [HandSkeleton.JointName: simd_float4x4] = [:]
                    for (jointName, _) in handComponent.forwardFingers {
                        jointPositions[jointName] =
                            handAnchor.originFromAnchorTransform
                            * handSkeleton.joint(jointName).anchorFromJointTransform
                    }
                    handComponent.checkMarkerCollisions(jointPositions: jointPositions)

                    // Add markers to scene if not already added
                    for marker in handComponent.markers {
                        if marker.parent == nil {
                            entity.parent?.addChild(marker)
                        }
                    }

                    // Check if all markers are collected
                    if handComponent.collectedMarkers == handComponent.currentRound {
                        // All markers collected, transition to pause state for next round
                        handComponent.startPause()
                    }
                }
            }

            // Update forward entities with hand-tracking data
            if let handSkeleton = handAnchor.handSkeleton {
                // Update forward entities to follow hand
                for (jointName, jointEntity) in handComponent.forwardFingers {
                    let anchorFromJointTransform = handSkeleton.joint(jointName)
                        .anchorFromJointTransform
                    jointEntity.setTransformMatrix(
                        handAnchor.originFromAnchorTransform * anchorFromJointTransform,
                        relativeTo: nil
                    )
                }

                // Update the component
                entity.components.set(handComponent)
            }
        }
    }

    /// Performs any necessary setup to the entities with the hand-tracking component.
    /// - Parameters:
    ///   - entity: The entity to perform setup on.
    ///   - handComponent: The hand-tracking component to update.
    func addJoints(to handEntity: Entity, handComponent: inout HandTrackingComponent) {
        let radius: Float = 0.012

        // Create forward entities
        let forwardMaterial = SimpleMaterial(
            color: .white,
            roughness: 0.1,
            isMetallic: false
        )
        let forwardSphereEntity = ModelEntity(
            mesh: .generateSphere(radius: radius),
            materials: [forwardMaterial]
        )

        // Create backward entities
        let backwardMaterial = SimpleMaterial(
            color: .red,
            roughness: 0.1,
            isMetallic: false
        )
        let backwardSphereEntity = ModelEntity(
            mesh: .generateSphere(radius: radius),
            materials: [backwardMaterial]
        )

        for bone in Hand.joints {
            // Add forward entity
            let forwardJoint = forwardSphereEntity.clone(recursive: false)
            handEntity.addChild(forwardJoint)
            handComponent.forwardFingers[bone.0] = forwardJoint

            // Add backward entity
            let backwardJoint = backwardSphereEntity.clone(recursive: false)
            handEntity.addChild(backwardJoint)
            handComponent.backwardFingers[bone.0] = backwardJoint
        }

        handEntity.components.set(handComponent)
    }
}

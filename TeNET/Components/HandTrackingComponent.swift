/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
A component that tracks an entity to a hand.
*/
import ARKit
import ARKit.hand_skeleton
import QuartzCore
import RealityKit

/// A frame of hand movement data
struct HandFrame {
    var jointTransforms: [HandSkeleton.JointName: simd_float4x4]
    var timestamp: TimeInterval
}

/// A component that tracks the hand skeleton.
struct HandTrackingComponent: Component {
    /// The chirality for the hand this component tracks.
    let chirality: AnchoringComponent.Target.Chirality

    /// A lookup that maps each joint name to its forward (tracking) entity.
    var forwardFingers: [HandSkeleton.JointName: Entity] = [:]

    /// A lookup that maps each joint name to its backward (playback) entity.
    var backwardFingers: [HandSkeleton.JointName: Entity] = [:]

    /// The current mode of the hand tracking
    enum TrackingMode {
        case idle
        case playing
        case pause
        case gameOver
    }

    /// Current tracking mode
    var mode: TrackingMode = .idle

    /// Recorded frames of hand movement for the current round
    var recordedFrames: [HandFrame] = []

    /// Playing frames of hand movement from previous rounds
    var playingFrames: [HandFrame] = []

    /// Stored frames from previous rounds
    private var storedFrames: [[HandFrame]] = []

    /// Recording start time
    var recordingStartTime: TimeInterval?

    /// Playback start time
    var playbackStartTime: TimeInterval?

    /// Current round number
    var currentRound: Int = 1

    /// Whether the hand is currently colliding with a past hand
    var isColliding: Bool = false

    /// Array of markers for the current round
    var markers: [Marker] = []

    /// Number of collected markers in the current round
    var collectedMarkers: Int = 0

    /// Collision threshold distance in meters
    static let collisionThreshold: Float = 0.03

    /// Marker collision threshold distance in meters
    static let markerCollisionThreshold: Float = 0.1

    /// Creates a new hand-tracking component.
    /// - Parameter chirality: The chirality of the hand target.
    init(chirality: AnchoringComponent.Target.Chirality) {
        self.chirality = chirality
        HandTrackingSystem.registerSystem()
    }

    /// Start recording mode
    mutating func startRound() {
        mode = .playing
        recordingStartTime = CACurrentMediaTime()
        playbackStartTime = CACurrentMediaTime()

        // Set up playback frames from only the previous round
        playingFrames = []
        if let previousRoundFrames = storedFrames.last {
            playingFrames = previousRoundFrames
        }

        // Reset marker collection state
        collectedMarkers = 0

        // Create markers for the current round
        markers = []
        for _ in 0..<currentRound {
            // Generate random position within reasonable play area
            let position = SIMD3<Float>(
                Float.random(in: -0.5...0.5),  // X: left/right
                Float.random(in: 1.0...1.5),  // Y: height
                Float.random(in: -0.3...0.3)  // Z: front/back
            )
            let marker = Marker(position: position)
            markers.append(marker)
        }
    }

    /// Check for collisions between hand joints and markers
    mutating func checkMarkerCollisions(jointPositions: [HandSkeleton.JointName: simd_float4x4]) {
        guard mode == .playing else { return }

        for marker in markers where !marker.isCollected {
            for position in jointPositions.values {
                let markerPosition = marker.position
                let jointPosition = SIMD3<Float>(
                    position.columns.3.x, position.columns.3.y, position.columns.3.z)
                let distance = length(markerPosition - jointPosition)

                if distance < Self.markerCollisionThreshold {
                    marker.isCollected = true
                    collectedMarkers += 1

                    // Update marker appearance to show it's collected
                    if var modelComponent = marker.components[ModelComponent.self] {
                        var material = SimpleMaterial(color: .green, isMetallic: false)
                        material.color = .init(tint: .green.withAlphaComponent(0.3))
                        modelComponent.materials = [material]
                        marker.components[ModelComponent.self] = modelComponent
                    }

                    break
                }
            }
        }
    }

    /// Start playback mode
    mutating func startPause() {
        mode = .pause
        // Store the current round's frames
        if !recordedFrames.isEmpty {
            storedFrames.append(recordedFrames)
            currentRound += 1
        }
        recordedFrames = []

        // Clean up markers from the previous round
        for marker in markers {
            marker.removeFromParent()
        }
        markers = []
    }

    /// Stop current mode
    mutating func stop() {
        recordingStartTime = nil
        playbackStartTime = nil

        switch mode {
        case .gameOver:
            // Reset everything if game is over
            recordedFrames = []
            storedFrames = []
            playingFrames = []
            currentRound = 1
            // Clean up markers
            for marker in markers {
                marker.removeFromParent()
            }
            markers = []
            mode = .idle
            isColliding = false
        case .pause:
            // Keep the recorded and stored frames for the next round
            mode = .idle
        case .playing:
            // If stopping from playing mode, transition to pause first
            startPause()
        case .idle:
            // Already in idle, no additional cleanup needed
            break
        }
    }
}

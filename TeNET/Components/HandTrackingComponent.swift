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

    /// Collision threshold distance in meters
    static let collisionThreshold: Float = 0.03

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
    }

    /// Stop current mode
    mutating func stop() {
        mode = .idle
        // Only clear the current round's recorded frames
        recordedFrames = []
        // Keep stored frames for next round
        recordingStartTime = nil
        playbackStartTime = nil

        if mode == .gameOver {
            // Reset everything only if game is over
            storedFrames = []
            playingFrames = []
            currentRound = 1
        }
    }
}

/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
A component that tracks an entity to a hand.
*/
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

    /// A lookup that maps each joint name to the entity that represents it.
    var fingers: [HandSkeleton.JointName: Entity] = [:]

    /// The current mode of the hand tracking
    enum TrackingMode {
        case recording
        case playing
        case idle
    }

    /// Current tracking mode
    var mode: TrackingMode = .idle

    /// Recorded frames of hand movement
    var recordedFrames: [HandFrame] = []

    /// Recording start time
    var recordingStartTime: TimeInterval?

    /// Playback start time
    var playbackStartTime: TimeInterval?

    /// Creates a new hand-tracking component.
    /// - Parameter chirality: The chirality of the hand target.
    init(chirality: AnchoringComponent.Target.Chirality) {
        self.chirality = chirality
        HandTrackingSystem.registerSystem()
    }

    /// Start recording mode
    mutating func startRecording() {
        mode = .recording
        recordedFrames = []
        recordingStartTime = CACurrentMediaTime()
    }

    /// Start playback mode
    mutating func startPlayback() {
        mode = .playing
        playbackStartTime = CACurrentMediaTime()
    }

    /// Stop current mode
    mutating func stop() {
        mode = .idle
        recordingStartTime = nil
        playbackStartTime = nil
    }
}

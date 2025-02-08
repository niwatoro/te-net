/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
The app's main view.
*/

import ARKit
import RealityKit
import SwiftUI

struct MainView: View {
    /// The environment value to get the `OpenImmersiveSpaceAction` instance.
    @Environment(\.openImmersiveSpace) var openImmersiveSpace

    /// The current tracking mode
    @State private var trackingMode: HandTrackingComponent.TrackingMode = .idle

    /// Reference to hand tracking entities
    @Binding var rightHandEntity: Entity?

    var body: some View {
        VStack {
            Text("Hand Tracking Example")
                .font(.title)
                .padding()

            switch trackingMode {
            case .idle:
                Button(action: startRecording) {
                    Text("Start Recording")
                        .font(.headline)
                        .padding()
                        .background(.blue)
                        .foregroundColor(.white)
                }
            case .recording:
                Text(
                    "Recording... \(10 - Int(CACurrentMediaTime() - (rightHandEntity?.components[HandTrackingComponent.self]?.recordingStartTime ?? 0)))s"
                )
                .font(.headline)
                .foregroundColor(.red)
            case .playing:
                Text("Playing...")
                    .font(.headline)
                    .foregroundColor(.green)
            }

            if trackingMode == .idle
                && (rightHandEntity?.components[HandTrackingComponent.self]?.recordedFrames.isEmpty
                    == false)
            {
                Button(action: startPlayback) {
                    Text("Play Recording")
                        .font(.headline)
                        .padding()
                        .background(.green)
                        .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            Task {
                await openImmersiveSpace(id: "HandTrackingScene")
            }
        }
    }

    private func startRecording() {
        guard let rightHand = rightHandEntity
        else {
            print("Failed to start recording: right hand entity not found")
            return
        }

        var rightComponent =
            rightHand.components[HandTrackingComponent.self]
            ?? HandTrackingComponent(chirality: .right)

        rightComponent.startRecording()

        rightHand.components.set(rightComponent)

        trackingMode = .recording

        // Automatically stop recording after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if trackingMode == .recording {
                stopRecording()
            }
        }
    }

    private func stopRecording() {
        updateHandComponents { component in
            component.stop()
        }
        trackingMode = .idle
    }

    private func startPlayback() {
        updateHandComponents { component in
            component.startPlayback()
        }
        trackingMode = .playing

        // Automatically stop playback after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if trackingMode == .playing {
                stopPlayback()
            }
        }
    }

    private func stopPlayback() {
        updateHandComponents { component in
            component.stop()
        }
        trackingMode = .idle
    }

    private func updateHandComponents(_ update: (inout HandTrackingComponent) -> Void) {
        guard
            let rightHand = rightHandEntity
        else {
            print("Failed to update hand components: right hand entity not found")
            return
        }

        var rightComponent =
            rightHand.components[HandTrackingComponent.self]
            ?? HandTrackingComponent(chirality: .right)

        update(&rightComponent)

        rightHand.components.set(rightComponent)
    }
}

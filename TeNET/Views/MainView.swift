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

    /// References to hand tracking entities
    @Binding var rightHandEntity: Entity?
    @Binding var leftHandEntity: Entity?

    /// The label showing the remaining time for recording or playback
    @State private var timerLabel: String = ""

    /// Current round number
    @State private var currentRound: Int = 1

    /// Best round achieved
    @State private var bestRound: Int = 0

    var body: some View {
        VStack {
            Text("TeNET")
                .font(.title)
                .padding()

            if bestRound > 0 {
                Text("Best: Round \(bestRound)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.bottom)
            }

            switch trackingMode {
            case .idle:
                Button(action: startRound) {
                    Text("Start Game")
                }
                .background(
                    .blue,
                    in: Capsule()
                )
            case .playing:
                Text("Round \(currentRound): \(timerLabel)s")
                    .foregroundColor(.green)
                    .padding()
            case .pause:
                Text("Round starts in \(timerLabel)s")
                    .foregroundColor(.green)
                    .padding()
            case .gameOver:
                VStack {
                    Text("Game Over!")
                        .foregroundColor(.red)
                        .padding()

                    Text("You reached Round \(currentRound)")
                        .padding(.bottom)

                    Button(action: restartGame) {
                        Text("Try Again")
                    }
                    .background(
                        .blue,
                        in: Capsule()
                    )
                }
            }
        }

        .onAppear {
            Task {
                await openImmersiveSpace(id: "HandTrackingScene")
            }
        }
    }

    private func startRound() {
        // Start recording for all hands
        updateHandComponents { component in
            component.startRound()
            component.currentRound = currentRound
        }

        trackingMode = .playing
        timerLabel = "10.00"

        // Create a strong reference to the timer
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) {
            timer in
            guard
                let component = rightHandEntity?.components[HandTrackingComponent.self],
                let startTime = component.recordingStartTime
            else {
                timer.invalidate()
                return
            }

            let elapsedTime = CACurrentMediaTime() - startTime
            var remainingTime = 10 - elapsedTime
            if remainingTime < 0 {
                remainingTime = 0
                // Ensure we transition to pause when time is up
                if trackingMode == .playing {
                    timer.invalidate()
                    currentRound += 1
                    startPause()
                }
            }
            timerLabel = String(format: "%.2f", remainingTime)

            // Check for game over
            if component.mode == .gameOver {
                timer.invalidate()
                trackingMode = .gameOver
                if currentRound > bestRound {
                    bestRound = currentRound
                }
            }
        }

        // Keep the timer alive
        RunLoop.current.add(timer, forMode: .common)
    }

    private func startPause() {
        updateHandComponents { component in
            component.startPause()
        }

        trackingMode = .pause
        timerLabel = "3.00"
        var remainingTime: Double = 3.0

        // Create a strong reference to the timer
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            remainingTime -= 0.1
            if remainingTime < 0 {
                remainingTime = 0
                // Ensure we transition to next round when pause timer is up
                if trackingMode == .pause {
                    timer.invalidate()
                    startRound()
                }
            }

            timerLabel = String(format: "%.2f", remainingTime)
        }

        // Keep the timer alive
        RunLoop.current.add(timer, forMode: .common)
    }

    private func restartGame() {
        updateHandComponents { component in
            component.stop()
        }

        currentRound = 1
        trackingMode = .idle
    }

    private func updateHandComponents(_ update: (inout HandTrackingComponent) -> Void) {
        // Update right hand
        if let rightHand = rightHandEntity {
            var component =
                rightHand.components[HandTrackingComponent.self]
                ?? HandTrackingComponent(chirality: .right)
            update(&component)
            rightHand.components.set(component)
        }

        // Update left hand
        if let lefthand = leftHandEntity {
            var component =
                lefthand.components[HandTrackingComponent.self]
                ?? HandTrackingComponent(chirality: .left)
            update(&component)
            lefthand.components.set(component)
        }
    }
}

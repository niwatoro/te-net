# TeNET - Interactive Hand Movement Game

TeNET is an immersive game that transforms your hand movements into an interactive gaming experience. Using cutting-edge ARKit and RealityKit frameworks, the game tracks and visualizes your hand movements in real-time, creating an engaging and intuitive gameplay environment. The name draws inspiration from Christopher Nolan's 2020 science fiction action thriller film "TENET", which explores the concept of time inversion.

## Game Features

- Intuitive gameplay using natural hand movements
- Real-time hand tracking for responsive gaming controls
- Interactive 3D visualization of both hands
- Immersive gaming space that responds to your movements
- Support for both left and right hand interactions
- Seamless integration of physical movements into gameplay

## Game Requirements

- macOS/iOS device with ARKit support
- Xcode 15.0 or later
- Swift 5.9 or later
- iOS 17.0 / macOS 14.0 or later

## Game Architecture

TeNET uses a robust Entity Component System (ECS) architecture to deliver smooth gameplay:

### Entities

- `Hand`: Your virtual hands in the game world
- `Finger`: Individual finger tracking for precise interactions
- `Bone`: Skeletal structure for realistic hand movements
- `Marker`: Tracking points for accurate movement detection

### Components

- `HandTrackingComponent`: Powers the game's hand movement detection

### Systems

- `HandTrackingSystem`: Processes your movements into game actions

### Views

- `MainView`: Primary game interface
- `HandTrackingView`: 3D visualization of your hands in the game world

## Project Structure

```
TeNET/
├── App/
│   └── HandTracking.swift       # Game entry point
├── Components/
│   └── HandTrackingComponent.swift
├── Entities/
│   ├── Hand.swift
│   ├── Finger.swift
│   ├── Bone.swift
│   └── Marker.swift
├── Systems/
│   └── HandTrackingSystem.swift
└── Views/
    ├── MainView.swift
    └── HandTrackingView.swift
```

## License

This project is licensed under the MIT License. See the [LICENSE.txt](LICENSE.txt) file for details.

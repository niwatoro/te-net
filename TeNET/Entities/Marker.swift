import RealityKit

class Marker: Entity {
    var isCollected: Bool = false

    init(position: SIMD3<Float>) {
        super.init()

        // Create a visual representation of the marker (a small sphere)
        let mesh = MeshResource.generateSphere(radius: 0.05)
        let material = SimpleMaterial(color: .blue, isMetallic: false)
        let modelComponent = ModelComponent(mesh: mesh, materials: [material])

        self.components[ModelComponent.self] = modelComponent
        self.position = position
        self.name = "marker"
    }

    required init() {
        fatalError("init() has not been implemented")
    }
}

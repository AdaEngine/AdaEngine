import AdaEngine
import Math
@_spi(Internal) import AdaRender
@_spi(Internal) import AdaInput
import AdaUtils
import Foundation

@main
struct SimpleCubeExample: App {
    var body: some AppScene {
        GameAppScene {
            let world = World()
            
            // 1. Setup Camera
            world.spawn("Camera", bundle: PerspectiveCameraBundle(
                camera: Camera(window: .primary),
                transform: Transform(position: [0, 2, 10])
            ))
            .components.insert(ScriptableComponents(scripts: [FlyCamera()]))
            
            // 2. Setup Cube
            let cubeMesh = generateCube()
            world.spawn("Cube", components: {
                Mesh3DComponent(mesh: cubeMesh, materials: [PBRMaterial()])
                Transform(position: [0, 1, 0])
            })
            
            // 3. Setup Floor
            let floorMesh = generatePlane(size: [20, 20])
            let floorMaterial = PBRMaterial()
            floorMaterial.baseColorFactor = [0, 1, 0, 1] // Green
            
            world.spawn("Floor", components: {
                Mesh3DComponent(mesh: floorMesh, materials: [floorMaterial])
                Transform(rotation: Quat.euler([-.pi / 2, 0, 0])) // Lay flat
            })
            
            let scene = Scene(from: world)
            return scene
        }
        .addPlugins(DefaultPlugins())
    }
}

final class FlyCamera: ScriptableObject, @unchecked Sendable {
    
    @RequiredComponent var cameraTransform: Transform
    
    var speed: Float = 5.0
    var sensitivity: Float = 5.0
    
    private var lastMousePosition: Vector2?
    private var rotation: Vector3 = .zero
    
    override func update(_ deltaTime: AdaUtils.TimeInterval) {
        let dt = Float(deltaTime)
        
        // 1. Handle Movement
        var direction: Vector3 = .zero
        
        if input.isKeyPressed(.w) { direction.z -= 1 }
        if input.isKeyPressed(.s) { direction.z += 1 }
        if input.isKeyPressed(.a) { direction.x -= 1 }
        if input.isKeyPressed(.d) { direction.x += 1 }
        if input.isKeyPressed(.e) { direction.y += 1 }
        if input.isKeyPressed(.q) { direction.y -= 1 }
        
        if direction != .zero {
            let rotationQuat = Quat.euler(self.rotation)
            let rotatedDirection = (Transform3D(quat: rotationQuat) * Vector4(direction.normalized, 1)).xyz
            cameraTransform.position += rotatedDirection * (speed * dt)
        }
        
        // 2. Handle Rotation
        if input.isMouseButtonPressed(.left) {
            let currentMousePosition = input.getMousePosition()
            
            if let lastPos = lastMousePosition {
                let delta = currentMousePosition - lastPos
                
                self.rotation.y -= delta.x * sensitivity * dt
                self.rotation.x -= delta.y * sensitivity * dt
                
                // Clamp pitch
                self.rotation.x = clamp(self.rotation.x, -1.5, 1.5)
                
                cameraTransform.rotation = Quat.euler(self.rotation)
            }
            
            lastMousePosition = currentMousePosition
        } else {
            lastMousePosition = nil
        }
    }
}

func generateCube() -> Mesh {
    let device = unsafe RenderEngine.shared.renderDevice
    var descriptor = MeshDescriptor(name: "Cube")
    
    // Vertices for a cube (each face has its own vertices for correct normals)
    let positions: [Vector3] = [
        // Front
        [-0.5, -0.5,  0.5], [ 0.5, -0.5,  0.5], [ 0.5,  0.5,  0.5], [-0.5,  0.5,  0.5],
        // Back
        [-0.5, -0.5, -0.5], [ 0.5, -0.5, -0.5], [ 0.5,  0.5, -0.5], [-0.5,  0.5, -0.5],
        // Top
        [-0.5,  0.5,  0.5], [ 0.5,  0.5,  0.5], [ 0.5,  0.5, -0.5], [-0.5,  0.5, -0.5],
        // Bottom
        [-0.5, -0.5,  0.5], [ 0.5, -0.5,  0.5], [ 0.5, -0.5, -0.5], [-0.5, -0.5, -0.5],
        // Right
        [ 0.5, -0.5,  0.5], [ 0.5,  0.5,  0.5], [ 0.5,  0.5, -0.5], [ 0.5, -0.5, -0.5],
        // Left
        [-0.5, -0.5,  0.5], [-0.5,  0.5,  0.5], [-0.5,  0.5, -0.5], [-0.5, -0.5, -0.5]
    ]
    
    let normals: [Vector3] = [
        // Front
        [0, 0, 1], [0, 0, 1], [0, 0, 1], [0, 0, 1],
        // Back
        [0, 0, -1], [0, 0, -1], [0, 0, -1], [0, 0, -1],
        // Top
        [0, 1, 0], [0, 1, 0], [0, 1, 0], [0, 1, 0],
        // Bottom
        [0, -1, 0], [0, -1, 0], [0, -1, 0], [0, -1, 0],
        // Right
        [1, 0, 0], [1, 0, 0], [1, 0, 0], [1, 0, 0],
        // Left
        [-1, 0, 0], [-1, 0, 0], [-1, 0, 0], [-1, 0, 0]
    ]
    
    descriptor.positions = MeshBuffer(positions)
    descriptor.normals = MeshBuffer(normals)
    
    descriptor.indicies = [
        0, 1, 2, 2, 3, 0,       // Front
        4, 6, 5, 6, 4, 7,       // Back
        8, 9, 10, 10, 11, 8,    // Top
        12, 14, 13, 14, 12, 15, // Bottom
        16, 17, 18, 18, 19, 16, // Right
        20, 22, 21, 22, 20, 23  // Left
    ]
    
    let part = Mesh.Part(
        id: 0,
        materialIndex: 0,
        primitiveTopology: .triangleList,
        isUInt32: true,
        meshDescriptor: descriptor,
        vertexDescriptor: descriptor.getMeshVertexBufferDescriptor(),
        indexBuffer: descriptor.getIndexBuffer(renderDevice: device),
        indexCount: descriptor.indicies.count,
        vertexBuffer: descriptor.getVertexBuffer(renderDevice: device)
    )
    
    return Mesh(models: [Mesh.Model(name: "Cube", parts: [part])])
}

func generatePlane(size: Vector2) -> Mesh {
    let device = unsafe RenderEngine.shared.renderDevice
    var descriptor = MeshDescriptor(name: "Plane")
    
    let halfWidth = size.x / 2
    let halfHeight = size.y / 2
    
    let positions: [Vector3] = [
        [-halfWidth, -halfHeight, 0],
        [ halfWidth, -halfHeight, 0],
        [ halfWidth,  halfHeight, 0],
        [-halfWidth,  halfHeight, 0]
    ]
    
    descriptor.positions = MeshBuffer(positions)
    descriptor.normals = MeshBuffer([[0, 0, 1], [0, 0, 1], [0, 0, 1], [0, 0, 1]])
    descriptor.indicies = [0, 1, 2, 2, 3, 0]
    
    let part = Mesh.Part(
        id: 0,
        materialIndex: 0,
        primitiveTopology: .triangleList,
        isUInt32: true,
        meshDescriptor: descriptor,
        vertexDescriptor: descriptor.getMeshVertexBufferDescriptor(),
        indexBuffer: descriptor.getIndexBuffer(renderDevice: device),
        indexCount: descriptor.indicies.count,
        vertexBuffer: descriptor.getVertexBuffer(renderDevice: device)
    )
    
    return Mesh(models: [Mesh.Model(name: "Plane", parts: [part])])
}

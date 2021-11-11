//
//  CameraManager.swift
//  
//
//  Created by v.prusakov on 11/2/21.
//

struct CameraData {
    var projection: Transform3D = .identity
    var view: Transform3D = .identity
    var position: Vector3 = .zero
}

public class CameraManager {
    
    public static let shared: CameraManager = CameraManager()
    
    public private(set) var currentCamera: CameraComponent?
    
    func setCurrentCamera(_ camera: CameraComponent) {
        self.currentCamera = camera
    }
    
    func makeCurrentCameraData(viewportSize: Vector2i) -> CameraData {
        guard let camera = self.currentCamera else { return CameraData() }
        
        let projection: Transform3D
        
        switch camera.projection {
        case .orthographic:
            projection = .identity
        case .perspective:
            projection = Transform3D.perspective(
                fieldOfView: camera.fieldOfView,
                aspectRatio: Float(viewportSize.x) / Float(viewportSize.y),
                zNear: camera.near,
                zFar: camera.far
            )
        }
        
        let position = camera.transform.worldPosition
        
        return CameraData(projection: projection, view: camera.transform.worldTransform, position: position)
    }
    
}

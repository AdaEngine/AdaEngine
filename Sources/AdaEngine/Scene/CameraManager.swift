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
    
    public private(set) var currentCamera: Camera?
    
    func setCurrentCamera(_ camera: Camera) {
        self.currentCamera?.isPrimal = false
        self.currentCamera = camera
        camera.isPrimal = true
        camera.viewportSize = RenderEngine.shared.renderBackend.viewportSize
    }
    
    func makeCurrentCameraData() -> CameraData {
        guard let camera = self.currentCamera else { return CameraData() }
        return camera.makeCameraData()
    }
    
}

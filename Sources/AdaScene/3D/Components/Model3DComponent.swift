//
//  Model3DComponent.swift
//  AdaEngine
//
//  Created by v.prusakov on 04/21/26.
//

import AdaECS
import AdaRender
import AdaAssets

/// A component that renders a 3D model.
public struct Model3DComponent: Component {
    public var model: AssetHandle<ModelAsset3D>
    
    public init(model: AssetHandle<ModelAsset3D>) {
        self.model = model
    }
}

//
//  AdaUI+Scene.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 29.05.2025.
//

import AdaUtils
import AdaUI

public extension EnvironmentValues {
    /// The game scene where view attached.
    @Entry internal(set) var scene: WeakBox<Scene>?
}

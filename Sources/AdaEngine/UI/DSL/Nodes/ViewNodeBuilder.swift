//
//  ViewNodeBuilder.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 08.06.2024.
//

protocol ViewNodeBuilder {
    @MainActor(unsafe)
    func makeViewNode(inputs: _ViewInputs) -> ViewNode
}

//
//  Text2DSystem.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 05.12.2025.
//

import AdaECS
import AdaTransform
import AdaText
import AdaRender
import Math

@System
@inline(__always)
func Text2DUpdateBoundings(
    _ texts: FilterQuery<
        Transform,
        TextLayoutComponent,
        Ref<BoundingComponent>,
        Changed<TextComponent>
    >
) async {
    await texts.parallel().forEach { transform, layout, bounds in
        let position = transform.position
        let scale = transform.scale
        let min = Vector3(position.x - scale.x / 2, position.y - scale.y / 2, 0)
        let max = Vector3(position.x + scale.x / 2, position.y + scale.y / 2, 0)
        bounds.bounds = .aabb(AABB(min: min, max: max))
    }
}

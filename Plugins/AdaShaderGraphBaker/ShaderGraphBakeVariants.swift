import AdaRender

enum ShaderGraphBakeVariants {
    /// Match PBRMaterial.shaderFeatures: an inactive layer removes its texture
    /// defines, while the specular extension is independent of the three layers.
    static func features(textureMask: UInt32, layers: UInt32, morph: Bool) -> PBRMaterial.ShaderFeatures {
        var textures = textureMask
        if layers & 1 == 0 { textures &= ~UInt32(0b111 << 3) }
        if layers & 2 == 0 { textures &= ~UInt32(0b11 << 6) }
        if layers & 4 == 0 { textures &= ~UInt32(1 << 8) }
        return .init(rawValue: textures | layers | (morph ? 1 << 11 : 0))
    }
}

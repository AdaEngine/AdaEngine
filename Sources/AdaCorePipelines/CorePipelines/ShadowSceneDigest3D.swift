@_spi(Internal) import AdaRender
import Math

/// A fingerprint of every shadow caster in the extracted scene, used to skip rebuilding per-face draw lists when
/// nothing a shadow face could draw has changed.
enum ShadowSceneDigest3D {
    /// The digest of the casters in `sources`, or `nil` when the scene cannot be summarized cheaply: a skinned caster
    /// changes pose without any change visible here, and with level-of-detail on, which mesh a caster draws
    /// depends on the camera.
    static func compute(sources: [Mesh3DRenderSource], usesLOD: Bool) -> UInt64? {
        var digest = FrameDigest3D()
        for index in sources.indices where sources[index].castShadows {
            if sources[index].skinningBuffer != nil || (usesLOD && !sources[index].alternatives.isEmpty) {
                return nil
            }
            digest.combine(sources[index].transform)
            digest.combine(UInt64(sources[index].forceVisible ? 1 : 0))
            for model in sources[index].mesh.models {
                for part in model.parts {
                    digest.combine(UInt64(UInt(bitPattern: ObjectIdentifier(part.vertexBuffer))))
                    digest.combine(UInt64(part.indexCount))
                    digest.combine(UInt64(part.materialIndex))
                }
            }
            for material in sources[index].materials {
                digest.combine(UInt64(UInt(bitPattern: ObjectIdentifier(material))))
                if let pbr = material as? PBRMaterial {
                    digest.combine(UInt64(truncatingIfNeeded: pbr.uniformRevision))
                    digest.combine(UInt64(pbr.baseColorTexture.map { UInt(bitPattern: ObjectIdentifier($0)) } ?? 0))
                }
            }
        }
        return digest.value
    }
}

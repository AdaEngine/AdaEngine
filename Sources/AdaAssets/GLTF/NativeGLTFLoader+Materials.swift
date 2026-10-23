import Math

extension NativeGLTFLoader {
    func importSamplers(_ gltf: GLTF) throws -> [GLTFImportResult.Sampler] {
        try (gltf.samplers ?? []).enumerated().map { index, sampler in
            let minFilter = sampler.minFilter ?? 9987
            let magFilter = sampler.magFilter ?? 9729
            let wrapS = sampler.wrapS ?? 10497
            let wrapT = sampler.wrapT ?? 10497
            guard [9728, 9729, 9984, 9985, 9986, 9987].contains(minFilter), [9728, 9729].contains(magFilter),
                  [10497, 33648, 33071].contains(wrapS), [10497, 33648, 33071].contains(wrapT)
            else { throw GLTFError.invalidSampler(index) }
            return .init(
                minFilter: minFilter,
                magFilter: magFilter,
                wrapS: wrapS,
                wrapT: wrapT
            )
        }
    }

    func importMaterials(_ gltf: GLTF) throws -> [GLTFImportResult.Material] {
        var result: [GLTFImportResult.Material] = []
        for (index, material) in (gltf.materials ?? []).enumerated() {
            result.append(try importMaterial(material, index: index, textureCount: (gltf.textures ?? []).count))
        }
        return result
    }

    /// The `KHR_texture_transform` of every texture slot (base color, metallic/roughness, normal, occlusion, emission).
    private func textureTransformInfos(_ material: GLTF.Material) -> [GLTF.TextureExtensions.Transform?] {
        let pbr = material.pbrMetallicRoughness
        var infos: [GLTF.TextureExtensions.Transform?] = []
        infos.append(pbr?.baseColorTexture?.extensions?.KHR_texture_transform)
        infos.append(pbr?.metallicRoughnessTexture?.extensions?.KHR_texture_transform)
        infos.append(material.normalTexture?.extensions?.KHR_texture_transform)
        infos.append(material.occlusionTexture?.extensions?.KHR_texture_transform)
        infos.append(material.emissiveTexture?.extensions?.KHR_texture_transform)
        return infos
    }

    private func isValid(_ info: GLTF.TextureExtensions.Transform?) -> Bool {
        guard let info else { return true }
        let offset: [Float] = info.offset ?? [0, 0]
        let scale: [Float] = info.scale ?? [1, 1]
        let values: [Float] = offset + scale + [info.rotation ?? 0]
        return offset.count == 2 && scale.count == 2 && values.allSatisfy { $0.isFinite }
    }

    /// Reads one extension texture reference. Returns `.absent` when there is none and `.invalid` when its index, UV set or
    /// transform cannot be used.
    private enum LayerReference {
        case absent
        case invalid
        case value(GLTFImportResult.TextureReference)
    }

    private func layerReference(_ reference: GLTF.Material.Extensions.TextureReference?, textureCount: Int) -> LayerReference {
        guard let reference else { return .absent }
        let transformInfo = reference.extensions?.KHR_texture_transform
        let texCoord = transformInfo?.texCoord ?? reference.texCoord ?? 0
        let scale: Float = reference.scale ?? 1
        guard reference.index >= 0, reference.index < textureCount, texCoord == 0 || texCoord == 1, scale.isFinite, isValid(transformInfo) else {
            return .invalid
        }
        var transform = GLTFImportResult.TextureTransform.identity
        if let transformInfo {
            let offset: [Float] = transformInfo.offset ?? [0, 0]
            let scaling: [Float] = transformInfo.scale ?? [1, 1]
            transform = .init(offset: Vector2(offset[0], offset[1]), rotation: transformInfo.rotation ?? 0, scale: Vector2(scaling[0], scaling[1]))
        }
        return .value(.init(index: reference.index, texCoord: texCoord, transform: transform, scale: scale))
    }

    private func importMaterial(_ material: GLTF.Material, index: Int, textureCount: Int) throws -> GLTFImportResult.Material {
        let pbr = material.pbrMetallicRoughness
        let base: [Float] = pbr?.baseColorFactor ?? [1, 1, 1, 1]
        let emissive: [Float] = material.emissiveFactor ?? [0, 0, 0]
        let metallic: Float = pbr?.metallicFactor ?? 1
        let roughness: Float = pbr?.roughnessFactor ?? 1
        let normalScale: Float = material.normalTexture?.scale ?? 1
        let occlusion: Float = material.occlusionTexture?.strength ?? 1
        let cutoff: Float = material.alphaCutoff ?? 0.5
        let strength: Float = material.extensions?.KHR_materials_emissive_strength?.emissiveStrength ?? 1
        let transformInfos = textureTransformInfos(material)
        // KHR_texture_transform may name another UV set for its texture.
        let authoredCoordinates: [Int] = [
            pbr?.baseColorTexture?.texCoord ?? 0,
            pbr?.metallicRoughnessTexture?.texCoord ?? 0,
            material.normalTexture?.texCoord ?? 0,
            material.occlusionTexture?.texCoord ?? 0,
            material.emissiveTexture?.texCoord ?? 0,
        ]
        var coordinates: [Int] = []
        for slot in authoredCoordinates.indices {
            coordinates.append(transformInfos[slot]?.texCoord ?? authoredCoordinates[slot])
        }
        let transformsAreValid = transformInfos.allSatisfy { isValid($0) }
        var transforms: [GLTFImportResult.TextureTransform] = []
        for info in transformInfos {
            guard let info, transformsAreValid else {
                transforms.append(.identity)
                continue
            }
            let offset: [Float] = info.offset ?? [0, 0]
            let scale: [Float] = info.scale ?? [1, 1]
            transforms.append(.init(offset: Vector2(offset[0], offset[1]), rotation: info.rotation ?? 0, scale: Vector2(scale[0], scale[1])))
        }
        let ior: Float = material.extensions?.KHR_materials_ior?.ior ?? 1.5
        let specular = material.extensions?.KHR_materials_specular
        let specularFactor: Float = specular?.specularFactor ?? 1
        let specularColor: [Float] = specular?.specularColorFactor ?? [1, 1, 1]
        let coat = material.extensions?.KHR_materials_clearcoat
        let clearcoatFactor: Float = coat?.clearcoatFactor ?? 0
        let clearcoatRoughness: Float = coat?.clearcoatRoughnessFactor ?? 0
        let sheen = material.extensions?.KHR_materials_sheen
        let sheenColor: [Float] = sheen?.sheenColorFactor ?? [0, 0, 0]
        let sheenRoughness: Float = sheen?.sheenRoughnessFactor ?? 0
        let anisotropy = material.extensions?.KHR_materials_anisotropy
        let layerInputs: [LayerReference] = [
            layerReference(coat?.clearcoatTexture, textureCount: textureCount),
            layerReference(coat?.clearcoatRoughnessTexture, textureCount: textureCount),
            layerReference(coat?.clearcoatNormalTexture, textureCount: textureCount),
            layerReference(sheen?.sheenColorTexture, textureCount: textureCount),
            layerReference(sheen?.sheenRoughnessTexture, textureCount: textureCount),
            layerReference(material.extensions?.KHR_materials_anisotropy?.anisotropyTexture, textureCount: textureCount),
            layerReference(material.extensions?.KHR_materials_specular?.specularTexture, textureCount: textureCount),
            layerReference(material.extensions?.KHR_materials_specular?.specularColorTexture, textureCount: textureCount),
        ]
        var layerValues: [GLTFImportResult.TextureReference?] = []
        var layerTexturesAreValid = true
        for input in layerInputs {
            switch input {
            case .absent: layerValues.append(nil)
            case .invalid:
                layerTexturesAreValid = false
                layerValues.append(nil)
            case let .value(value): layerValues.append(value)
            }
        }
        let anisotropyStrength: Float = anisotropy?.anisotropyStrength ?? 0
        let anisotropyRotation: Float = anisotropy?.anisotropyRotation ?? 0
        let textures: [Int?] = [
            pbr?.baseColorTexture?.index,
            pbr?.metallicRoughnessTexture?.index,
            material.normalTexture?.index,
            material.occlusionTexture?.index,
            material.emissiveTexture?.index,
        ]
        let unitValues: [Float] = base + emissive + [metallic, roughness, occlusion]
        let texturesExist = textures.compactMap { $0 }.allSatisfy { $0 >= 0 && $0 < textureCount }
        let factorsAreValid = base.count == 4 && emissive.count == 3 && unitValues.allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 1 }
        let scalarsAreValid = normalScale.isFinite && cutoff.isFinite && cutoff >= 0 && strength.isFinite && strength >= 0
        let coatIsValid = clearcoatFactor.isFinite && clearcoatFactor >= 0 && clearcoatFactor <= 1
            && clearcoatRoughness.isFinite && clearcoatRoughness >= 0 && clearcoatRoughness <= 1
        let sheenIsValid = sheenColor.count == 3 && sheenColor.allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 1 }
            && sheenRoughness.isFinite && sheenRoughness >= 0 && sheenRoughness <= 1
        let anisotropyIsValid = anisotropyStrength.isFinite && anisotropyStrength >= 0 && anisotropyStrength <= 1 && anisotropyRotation.isFinite
        let specularIsValid = ior.isFinite && ior >= 1 && ior <= 100 && specularFactor.isFinite && specularFactor >= 0
            && specularColor.count == 3 && specularColor.allSatisfy { $0.isFinite && $0 >= 0 }
        guard factorsAreValid, scalarsAreValid, specularIsValid, coatIsValid, sheenIsValid, anisotropyIsValid, layerTexturesAreValid, texturesExist, transformsAreValid,
              coordinates.allSatisfy({ $0 == 0 || $0 == 1 }),
              let alpha = GLTFImportResult.AlphaMode(rawValue: material.alphaMode ?? "OPAQUE")
        else { throw GLTFError.invalidMaterial(index) }
        return .init(
            name: material.name,
            baseColorFactor: Vector4(base[0], base[1], base[2], base[3]),
            baseColorTextureIndex: textures[0],
            metallicFactor: metallic,
            roughnessFactor: roughness,
            metallicRoughnessTextureIndex: textures[1],
            normalTextureIndex: textures[2],
            normalScale: normalScale,
            occlusionTextureIndex: textures[3],
            occlusionStrength: occlusion,
            emissiveTextureIndex: textures[4],
            emissiveFactor: Vector3(emissive[0], emissive[1], emissive[2]),
            emissiveStrength: strength,
            alphaMode: alpha,
            alphaCutoff: cutoff,
            doubleSided: material.doubleSided ?? false,
            textureCoordinates: coordinates,
            textureTransforms: transforms,
            ior: ior,
            specularFactor: specularFactor,
            specularColorFactor: Vector3(specularColor[0], specularColor[1], specularColor[2]),
            clearcoatFactor: clearcoatFactor,
            clearcoatRoughnessFactor: clearcoatRoughness,
            sheenColorFactor: Vector3(sheenColor[0], sheenColor[1], sheenColor[2]),
            sheenRoughnessFactor: sheenRoughness,
            anisotropyStrength: anisotropyStrength,
            anisotropyRotation: anisotropyRotation,
            layerTextures: GLTFImportResult.LayerTextures(
                clearcoat: layerValues[0],
                clearcoatRoughness: layerValues[1],
                clearcoatNormal: layerValues[2],
                sheenColor: layerValues[3],
                sheenRoughness: layerValues[4],
                anisotropy: layerValues[5],
                specular: layerValues[6],
                specularColor: layerValues[7]
            )
        )
    }
}

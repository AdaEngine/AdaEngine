import AdaECS
@_spi(Internal) import AdaRender
import AdaUtils
import Math

/// The camera's compact draw buffers. DrawPass reads these only while the main 3D node encodes that view.
public struct Active3DInstanceBuffers: Resource {
    public var instances: BufferData<Flat3DInstanceData>?
    public var defaults: BufferData<Flat3DDefaultVertexData>?
    public var indirectArguments: (any Buffer)?
    public init() {}
}

/// Compact, frame-buffered draw lists per camera and per shadow cascade.
public struct VisibleMesh3DLists: Resource {
    private struct Key: Hashable {
        var view: Entity.ID
        var pass: Int
    }
    private struct Entry {
        var buffers = Opaque3DInstanceBuffers()
        var items: [Opaque3DRenderItem] = []
        var candidates: [GPUVisibilityCandidate] = []
        var count = Visibility3DCount()
        var records: [Record] = []
        var order: [Int32] = []
    }

    private struct SelectionKey: Hashable {
        var view: Entity.ID
        var entity: Entity.ID
    }
    private struct BatchKey: Hashable {
        var vertex: ObjectIdentifier
        var index: ObjectIdentifier
        var material: RID
        var skin: ObjectIdentifier?
        var cast: Bool
        var receive: Bool
    }

    /// What a part contributes to a batch that does not depend on which source it came from. Built once per
    /// distinct batch per call instead of once per visible part.
    private struct BatchTemplate {
        var color: Vector4
        var material: Vector4
        var textureFlags: Vector4
        var shadowFlags: Vector4
        var blended: Bool
        /// Batch order, assigned when the first record of this batch is appended.
        var rank: Int
    }

    /// A visible part, kept free of references so building, ordering and reading thousands of them costs no
    /// reference counting.
    private struct Record {
        var source: Int32
        var lod: Int32
        var model: Int32
        var part: Int32
        var material: Int32
        var template: Int32
        var fade: Float
    }

    private var entries: [Key: Entry] = [:]
    private var history: [SelectionKey: Int] = [:]
    public init() {}

    public mutating func retainViews(_ views: [Entity.ID]) {
        for key in entries.keys where !views.contains(key.view) { entries.removeValue(forKey: key) }
        for key in history.keys where !views.contains(key.view) { history.removeValue(forKey: key) }
    }

    public mutating func prepare(
        sources: [Mesh3DRenderSource],
        view: Entity.ID,
        pass: Int,
        viewMatrix: Transform3D,
        projection: Transform3D,
        cullingProjection: Transform3D,
        settings: MeshVisibilitySettings3D,
        device: RenderDevice,
        materials: inout PBR3DUniforms
    ) {
        let key = Key(view: view, pass: pass)
        var entry = entries.removeValue(forKey: key) ?? Entry()
        entry.items.removeAll(keepingCapacity: true)
        entry.buffers.beginFrame()
        entry.records.removeAll(keepingCapacity: true)
        entry.order.removeAll(keepingCapacity: true)
        entry.candidates.removeAll(keepingCapacity: true)
        entry.count = Visibility3DCount()
        let cameraPosition = viewMatrix.inverse.origin
        let frustum = MeshVisibilityFrustum3D(viewProjection: cullingProjection)
        let isShadowPass = pass >= 0
        var templateIndex: [BatchKey: Int32] = [:]
        var templates: [BatchTemplate] = []
        var rankCount = 0
        // The loops read fields straight from the array instead of binding each source: a source is a large value
        // with several references, and copying it for every pass and every mesh dominated this function.
        for sourceIndex in sources.indices {
            if isShadowPass && !sources[sourceIndex].castShadows { continue }
            entry.count.candidates += 1
            if settings.frustumCulling, !sources[sourceIndex].forceVisible, let bounds = sources[sourceIndex].bounds,
                !frustum.intersects(bounds) {
                entry.count.frustumRejected += 1
                continue
            }
            var fade: Float = 1
            if settings.distanceCulling, let maximum = sources[sourceIndex].maximumDistance, maximum.isFinite, maximum > 0 {
                let center = sources[sourceIndex].bounds?.center ?? sources[sourceIndex].transform.origin
                let distance = (center - cameraPosition).length
                if distance >= maximum {
                    entry.count.distanceRejected += 1
                    continue
                }
                let fadeDistance = finiteRenderValue(sources[sourceIndex].fadeDistance, fallback: 4, range: 0...maximum)
                if fadeDistance > 0 { fade = min(max((maximum - distance) / fadeDistance, 0), 1) }
            }
            var lod = 0
            // A mesh with no alternatives is always level zero; skipping the selection also keeps it out of the
            // hysteresis history, which only matters for meshes that can change level.
            if settings.lod, !sources[sourceIndex].alternatives.isEmpty, let bounds = sources[sourceIndex].bounds {
                let selectionKey = SelectionKey(view: view, entity: sources[sourceIndex].entity)
                lod = MeshVisibility3DMath.selectLOD(
                    size: MeshVisibility3DMath.projectedDiameter(bounds, view: viewMatrix, projection: projection),
                    thresholds: sources[sourceIndex].thresholds,
                    levels: sources[sourceIndex].alternatives.count + 1,
                    previous: history[selectionKey],
                    hysteresis: sources[sourceIndex].hysteresis
                )
                history[selectionKey] = lod
            }
            entry.count.visibleMeshes += 1
            entry.count.lodInstances[min(lod, 2)] += 1
            let sourceMesh = sources[sourceIndex].mesh
            for modelIndex in sourceMesh.models.indices {
                for partIndex in sourceMesh.models[modelIndex].parts.indices {
                    entry.count.lod0Triangles += sourceMesh.models[modelIndex].parts[partIndex].indexCount / 3
                }
            }
            let mesh = lod == 0 ? sourceMesh : sources[sourceIndex].alternatives[lod - 1]
            for modelIndex in mesh.models.indices {
                let parts = mesh.models[modelIndex].parts
                for partIndex in parts.indices {
                    let materialIndex = parts[partIndex].materialIndex
                    guard sources[sourceIndex].materials.indices.contains(materialIndex) else { continue }
                    let material = sources[sourceIndex].materials[materialIndex]
                    let batchKey = BatchKey(
                        vertex: ObjectIdentifier(parts[partIndex].vertexBuffer),
                        index: ObjectIdentifier(parts[partIndex].indexBuffer),
                        material: material.rid,
                        skin: sources[sourceIndex].skinningBuffer.map(ObjectIdentifier.init),
                        cast: sources[sourceIndex].castShadows,
                        receive: sources[sourceIndex].receiveShadows
                    )
                    let template: Int32
                    if let existing = templateIndex[batchKey] {
                        template = existing
                        if isShadowPass && templates[Int(template)].blended { continue }
                    } else {
                        let blended = (material as? PBRMaterial)?.alphaMode == .blend
                        if isShadowPass && blended {
                            // Remember the decision so later parts of this batch skip without rebuilding it.
                            templateIndex[batchKey] = Int32(templates.count)
                            templates.append(BatchTemplate(color: .one, material: .zero, textureFlags: .zero, shadowFlags: .zero, blended: true, rank: -1))
                            continue
                        }
                        // Written once per batch: the uniform depends only on the material and vertex layout.
                        materials.write(material: material, descriptor: parts[partIndex].vertexDescriptor, device: device)
                        template = Int32(templates.count)
                        templateIndex[batchKey] = template
                        templates.append(Self.makeTemplate(
                            material: material,
                            descriptor: parts[partIndex].vertexDescriptor,
                            receivesShadows: sources[sourceIndex].receiveShadows,
                            blended: blended
                        ))
                    }
                    if templates[Int(template)].rank < 0 {
                        templates[Int(template)].rank = rankCount
                        rankCount += 1
                    }
                    entry.records.append(Record(
                        source: Int32(sourceIndex),
                        lod: Int32(lod),
                        model: Int32(modelIndex),
                        part: Int32(partIndex),
                        material: Int32(materialIndex),
                        template: template,
                        fade: fade
                    ))
                    entry.count.triangles += parts[partIndex].indexCount / 3
                }
            }
        }
        // Keep opaque buckets adjacent before packing: opaque batches first, each in the order it was first seen and
        // each keeping its records in submission order. BLEND remains one draw per instance and is depth-sorted by
        // Main3DRenderNode, preserving transparent compositing semantics. A counting placement does this in linear time.
        let bucketCount = rankCount * 2
        var offsets = [Int32](repeating: 0, count: bucketCount + 1)
        for record in entry.records {
            let template = templates[Int(record.template)]
            offsets[(template.blended ? rankCount : 0) + template.rank + 1] += 1
        }
        for bucket in 0..<bucketCount { offsets[bucket + 1] += offsets[bucket] }
        entry.order = [Int32](repeating: 0, count: entry.records.count)
        for (recordIndex, record) in entry.records.enumerated() {
            let template = templates[Int(record.template)]
            let bucket = (template.blended ? rankCount : 0) + template.rank
            entry.order[Int(offsets[bucket])] = Int32(recordIndex)
            offsets[bucket] += 1
        }
        var previousTemplate: Int32 = -1
        for orderIndex in entry.order {
            let record = entry.records[Int(orderIndex)]
            let sourceIndex = Int(record.source)
            let template = templates[Int(record.template)]
            var shadowFlags = template.shadowFlags
            shadowFlags.w = 1 - record.fade
            let instanceIndex = entry.buffers.append(Flat3DInstanceData(
                modelMatrix: sources[sourceIndex].transform,
                color: template.color,
                material: template.material,
                textureFlags: template.textureFlags,
                shadowFlags: shadowFlags,
                previousModelMatrix: sources[sourceIndex].previousTransform
            ))
            if !template.blended, previousTemplate == record.template, let last = entry.items.indices.last {
                let lower = entry.items[last].batchRange?.lowerBound ?? instanceIndex
                entry.items[last].batchRange = lower..<(instanceIndex + 1)
            } else {
                let mesh = record.lod == 0 ? sources[sourceIndex].mesh : sources[sourceIndex].alternatives[Int(record.lod) - 1]
                entry.items.append(
                    Opaque3DRenderItem(
                        entity: sources[sourceIndex].entity,
                        drawPass: sources[sourceIndex].drawPass,
                        sortKey: 0,
                        modelIndex: Int(record.model),
                        partIndex: Int(record.part),
                        mesh: mesh,
                        material: sources[sourceIndex].materials[Int(record.material)],
                        worldTransform: sources[sourceIndex].transform,
                        castShadows: sources[sourceIndex].castShadows,
                        receiveShadows: sources[sourceIndex].receiveShadows,
                        batchRange: instanceIndex..<(instanceIndex + 1),
                        skinningBuffer: sources[sourceIndex].skinningBuffer
                    )
                )
            }
            if pass < 0 && settings.gpuOcclusion, let item = entry.items.last, let range = item.batchRange {
                entry.candidates.append(
                    GPUVisibilityCandidate(
                        bounds: sources[sourceIndex].bounds,
                        draw: UInt32(entry.items.count - 1),
                        source: UInt32(instanceIndex),
                        destination: UInt32(range.lowerBound),
                        forceVisible: sources[sourceIndex].forceVisible || template.blended
                    )
                )
            }
            previousTemplate = template.blended ? -1 : record.template
        }
        entry.buffers.write(to: device)
        entry.count.drawCalls = entry.items.count
        entries[key] = entry
    }

    public func gpuCandidates(view: Entity.ID, pass: Int) -> [GPUVisibilityCandidate] { entries[Key(view: view, pass: pass)]?.candidates ?? [] }

    public func items(view: Entity.ID, pass: Int) -> [Opaque3DRenderItem] { entries[Key(view: view, pass: pass)]?.items ?? [] }
    public func count(view: Entity.ID, pass: Int) -> Visibility3DCount { entries[Key(view: view, pass: pass)]?.count ?? Visibility3DCount() }
    public func buffers(view: Entity.ID, pass: Int) -> Active3DInstanceBuffers {
        var result = Active3DInstanceBuffers()
        if let entry = entries[Key(view: view, pass: pass)] {
            result.instances = entry.buffers.currentBuffer
            result.defaults = entry.buffers.defaultVertexBuffer
        }
        return result
    }

    private static func makeTemplate(material: Material, descriptor: VertexDescriptor, receivesShadows: Bool, blended: Bool) -> BatchTemplate {
        let pbr = material as? PBRMaterial
        let atmosphere = material as? AtmosphereMaterial
        func hasUV(_ slot: Int) -> Bool {
            let set = pbr?.textureCoordinates.indices.contains(slot) == true ? pbr?.textureCoordinates[slot] ?? 0 : 0
            return descriptor.attributes.containsAttribute(by: set == 1 ? MeshDescriptor.textureCoordinates1.id.name : MeshDescriptor.textureCoordinates.id.name)
        }
        return BatchTemplate(
            color: pbr?.baseColorFactor ?? .one,
            material: [pbr?.roughnessFactor ?? 1, pbr?.metallicFactor ?? 0, pbr?.emissiveStrength ?? 0, pbr?.emissiveLightThreshold ?? -1],
            textureFlags: [
                hasUV(0) && pbr?.baseColorTexture != nil ? 1 : 0,
                hasUV(1) && pbr?.metallicRoughnessTexture != nil ? 1 : 0,
                hasUV(2) && pbr?.normalTexture != nil ? 1 : 0,
                descriptor.attributes.containsAttribute(by: MeshDescriptor.tangents.id.name) ? 1 : 0,
            ],
            shadowFlags: [receivesShadows ? 1 : 0, atmosphere?.fresnelPower ?? 0, atmosphere?.atmosphereIntensity ?? 0, 0],
            blended: blended,
            rank: -1
        )
    }
}

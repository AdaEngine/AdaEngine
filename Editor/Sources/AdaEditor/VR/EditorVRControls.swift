import AdaEngine
import Foundation

enum EditorVRPanel: String, CaseIterable, Hashable {
    case project
    case hierarchy
    case inspector
    case assets
    case navigation
    case studio
    case files
    case code
    case console
    case agent
    case voice
    case settings

    var windowID: String { "vr-ui-\(rawValue)" }
}

extension EditorSceneViewportTool {
    var vrSymbol: String {
        switch self {
        case .select: "\u{E569}"
        case .translate: symbol
        case .rotate: symbol
        case .scale: "\u{E3A5}"
        }
    }

    var spatialMode: SpatialManipulationMode {
        switch self {
        case .select: .select
        case .translate: .translate
        case .rotate: .rotate
        case .scale: .scale
        }
    }
}

extension EditorVRWorkspace {
    var canChangeProject: Bool { !isImmersed && !isOpening && document?.isDirty != true }
    var canEdit: Bool { document?.isReadOnly == false && !isManipulating && !isNavigating }
    var canUndo: Bool { canEdit && !(workbench.sceneUndoHistory[document?.id ?? ""] ?? []).isEmpty }
    var canRedo: Bool { canEdit && !(workbench.sceneRedoHistory[document?.id ?? ""] ?? []).isEmpty }
    var canSave: Bool { canEdit && document?.isDirty == true }
    var selectedName: String? { inspector.selectedEntity?.name }

    var saveStatus: String {
        if saveFailure != nil {
            return "Save failed"
        }
        guard let document else {
            return "No scene"
        }
        if document.isReadOnly {
            return "Read only"
        }
        return document.isDirty ? "Modified" : "Saved"
    }

    func setPanel(_ panel: EditorVRPanel, visible: Bool) {
        if visible { presentedPanels.insert(panel) } else { presentedPanels.remove(panel) }
    }

    func addAsset(_ asset: EditorAssetDocument) {
        guard canEdit, let document else {
            return
        }
        edit { _ = self.workbench.addModelAsset(asset, to: document.id) }
    }

    func duplicateSelection() {
        guard canEdit, let document, let id = inspector.selectedEntity?.editorID else {
            return
        }
        edit { self.workbench.duplicateSceneEntity(documentID: document.id, entityID: id) }
    }
}

enum EditorVRPrimitive: String, CaseIterable {
    case cube = "Cube"
    case sphere = "Sphere"
    case plane = "Plane"
}

extension EditorVRWorkspace {
    func addPrimitive(_ primitive: EditorVRPrimitive) {
        guard canEdit else {
            return
        }
        edit {
            self.modifyDocument { model in
                let entity = model.addEntity(template: .model3D, parentID: nil)
                guard let index = model.entities.firstIndex(where: { $0.id == entity.id }) else {
                    return
                }
                model.entities[index].name = primitive.rawValue
                model.entities[index].components[EditorBuiltInComponentType.mesh3D]?["mesh"] = .string(primitive.rawValue)
                model.entities[index].components[EditorBuiltInComponentType.transform]?["position"] = .array([.double(0), .double(1), .double(1.5)])
            }
        }
    }
}

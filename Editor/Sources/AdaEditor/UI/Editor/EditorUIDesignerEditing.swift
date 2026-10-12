@_spi(AdaEngine) import AdaEngine
import Math

struct EditorUIDropSlot: Equatable {
    let parentID: String
    var modifierID: String?
    var index: Int
}

enum EditorUIDropDestination: Equatable {
    case children(EditorUIDropSlot)
    case free(parentID: String?, position: Point)
}

extension EditorUISceneModel {
    func node(_ id: String) -> UINodeDescription? {
        var result: UINodeDescription?
        document.root.visit { if $0.id == id { result = $0 } }
        return result
    }

    func makeDesignerNode(_ type: String) -> UINodeDescription? {
        guard let signature = catalog.views[type]?.signature else {
            return nil
        }
        var node = UINodeDescription(type: type)
        for parameter in signature.parameters {
            if let value = parameter.defaultValue { node.arguments[parameter.name] = .init(value: value) }
        }
        return node
    }

    func dropSlot(containing id: String) -> EditorUIDropSlot? {
        var result: EditorUIDropSlot?
        document.root.visit { parent in
            if let index = parent.children.firstIndex(where: { $0.id == id }) {
                result = .init(parentID: parent.id, index: index)
            }
            for modifier in parent.modifiers {
                if let index = modifier.children.firstIndex(where: { $0.id == id }) {
                    result = .init(parentID: parent.id, modifierID: modifier.id, index: index)
                }
            }
        }
        return result
    }

    func canDrop(_ moving: UINodeDescription, at destination: EditorUIDropDestination) -> Bool {
        guard !isReadOnly, !isInteractive, !showsSource, moving.id != document.root.id else {
            return false
        }
        let parentID: String?
        switch destination {
        case let .children(slot):
            parentID = slot.parentID
            guard let parent = node(slot.parentID) else {
                return false
            }
            let shape: UIContentShape?
            let children: [UINodeDescription]
            if let modifierID = slot.modifierID {
                guard let modifier = parent.modifiers.first(where: { $0.id == modifierID }) else {
                    return false
                }
                shape = catalog.modifiers[modifier.type]?.signature.content
                children = modifier.children
            } else {
                shape = catalog.views[parent.type]?.signature.content
                children = parent.children
            }
            guard shape == .children || shape == .single && children.filter({ $0.id != moving.id }).isEmpty else {
                return false
            }
        case let .free(id, position):
            parentID = id
            guard position.x.isFinite, position.y.isFinite, (0...1).contains(position.x), (0...1).contains(position.y) else {
                return false
            }
            if let id, node(id)?.type != "FreeLayout" {
                return false
            }
        }
        var cyclic = false
        moving.visit { if $0.id == parentID { cyclic = true } }
        return !cyclic
    }

    /// A complete drop, including wrapping the old root, is one document/history transaction.
    @discardableResult
    func dropDesignerNode(_ proposed: UINodeDescription, at destination: EditorUIDropDestination) -> Bool {
        guard canDrop(proposed, at: destination) else {
            return false
        }
        let original = document
        let source = dropSlot(containing: proposed.id)
        var moving = node(proposed.id) ?? proposed
        let parentID: String?
        switch destination {
        case let .children(slot):
            parentID = slot.parentID
            moving.modifiers.removeAll { $0.type == "relativePosition" }
            edit { document in
                Self.removeDesignerNode(&document.root, id: moving.id)
                Self.modify(&document.root, id: slot.parentID) { parent in
                    var index = slot.index
                    if let source, source.parentID == slot.parentID, source.modifierID == slot.modifierID, source.index < index { index -= 1 }
                    if let modifierID = slot.modifierID, let modifier = parent.modifiers.firstIndex(where: { $0.id == modifierID }) {
                        parent.modifiers[modifier].children.insert(moving, at: min(max(0, index), parent.modifiers[modifier].children.count))
                    } else {
                        parent.children.insert(moving, at: min(max(0, index), parent.children.count))
                    }
                }
            }
        case let .free(id, position):
            parentID = id
            // YAML's numeric formatting must round-trip the authored fractions exactly.
            let x = (Double(position.x) * 1_000_000).rounded() / 1_000_000
            let y = (Double(position.y) * 1_000_000).rounded() / 1_000_000
            let arguments: [String: UIArgument] = ["x": .init(value: .number(x)), "y": .init(value: .number(y))]
            if let index = moving.modifiers.lastIndex(where: { $0.type == "relativePosition" }) {
                moving.modifiers[index].arguments = arguments
            } else {
                moving.modifiers.append(.init(type: "relativePosition", arguments: arguments))
            }
            edit { document in
                Self.removeDesignerNode(&document.root, id: moving.id)
                if let id {
                    Self.modify(&document.root, id: id) { parent in
                        let index = source?.parentID == id && source?.modifierID == nil ? source?.index ?? parent.children.count : parent.children.count
                        parent.children.insert(moving, at: min(index, parent.children.count))
                    }
                } else {
                    document.root = .init(type: "FreeLayout", children: [document.root, moving])
                }
            }
        }
        guard document != original else {
            return false
        }
        selectedID = moving.id
        insertionModifierID = nil
        if let parentID { collapsedLayerIDs.remove(parentID) }
        return true
    }

    private static func removeDesignerNode(_ node: inout UINodeDescription, id: String) {
        node.children.removeAll { $0.id == id }
        for index in node.children.indices { removeDesignerNode(&node.children[index], id: id) }
        for modifier in node.modifiers.indices {
            node.modifiers[modifier].children.removeAll { $0.id == id }
            for index in node.modifiers[modifier].children.indices { removeDesignerNode(&node.modifiers[modifier].children[index], id: id) }
        }
    }
}

//
//  SystemsGraphTests.swift
//  AdaEngine
//

@testable import AdaECS
import Testing

@Suite("Systems graph identity")
struct SystemsGraphTests {
    @Test("Type dependencies resolve custom system identifiers")
    func typeDependenciesResolveCustomIdentifiers() {
        var graph = SystemsGraph()
        graph.addSystem(CustomIdentifierSystem(identifier: "custom.first"))
        graph.addSystem(CustomIdentifierSystem(identifier: "custom.second"))
        graph.addSystem(DependentIdentifierSystem(world: World()))

        graph.linkSystems()

        let dependentName = DependentIdentifierSystem.swiftName
        #expect(graph.getOuputNodes(for: "custom.first").map(\.name) == [dependentName])
        #expect(graph.getOuputNodes(for: "custom.second").map(\.name) == [dependentName])
        #expect(Set(graph.getInputNodes(for: dependentName).map(\.name)) == ["custom.first", "custom.second"])
    }

    @Test("Type removal removes all custom-identified instances")
    func typeRemovalRemovesCustomIdentifiedInstances() {
        var graph = SystemsGraph()
        graph.addSystem(CustomIdentifierSystem(identifier: "custom.first"))
        graph.addSystem(CustomIdentifierSystem(identifier: "custom.second"))

        graph.removeSystem(CustomIdentifierSystem.self)

        #expect(graph.nodes.isEmpty)
    }
}

private struct CustomIdentifierSystem: System {
    let systemIdentifier: String

    init(identifier: String) {
        self.systemIdentifier = identifier
    }

    init(world: World) {
        self.systemIdentifier = "custom.default"
    }

    func update(context: UpdateContext) async {}
}

private struct DependentIdentifierSystem: System {
    static let dependencies: [SystemDependency] = [
        .after(CustomIdentifierSystem.self)
    ]

    init(world: World) {}

    func update(context: UpdateContext) async {}
}

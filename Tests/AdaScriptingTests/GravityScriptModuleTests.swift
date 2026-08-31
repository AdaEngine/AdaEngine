@testable import AdaApp
import AdaECS
import AdaScripting
import Testing

@Suite("Multi-file Gravity modules", .serialized)
struct GravityScriptModuleTests {
    @Test("Runs imported helpers and multiple system roots in one module")
    @MainActor
    func runsMultiFileModule() async throws {
        ModulePosition.registerComponent()
        ModuleCounter.registerComponent()

        let plugin = try GravityScriptPlugin(
            sources: Self.multiFileSources,
            name: "MultiFileTest"
        )

        let world = World(name: "Multi-file Gravity module")
        let entity = world.spawn {
            ModulePosition(value: 1)
            ModuleCounter(value: 10)
        }
        plugin.setup(in: AppWorlds(main: world))
        await world.runScheduler(.update)

        #expect(plugin.diagnostics.isEmpty)
        #expect(world.get(ModulePosition.self, from: entity.id)?.value == 4)
        #expect(world.get(ModuleCounter.self, from: entity.id)?.value == 12)
    }

    @Test("Reports the complete reachable import cycle")
    func reportsImportCycle() {
        #expect {
            try GravityScriptPlugin(
                sources: [
                    GravityScriptSource(
                        path: "A.ada",
                        source: """
                        import { helper } from "./B";

                        @system
                        class CycleSystem {
                            func update(context) {}
                        }
                        """
                    ),
                    GravityScriptSource(
                        path: "B.ada",
                        source: """
                        import { CycleSystem } from "./A";
                        func helper() {}
                        """
                    )
                ],
                name: "Cycle"
            )
        } throws: { error in
            (error as? GravityScriptError) == .importCycle(["A.ada", "B.ada", "A.ada"])
        }
    }

    @Test("Rejects imports that escape the target source map")
    func rejectsEscapingImport() {
        #expect(throws: GravityScriptError.self) {
            try GravityScriptPlugin(
                sources: [
                    GravityScriptSource(
                        path: "Systems/Unsafe.ada",
                        source: """
                        import { Secret } from "../../Secret";

                        @system
                        class UnsafeSystem {
                            func update(context) {}
                        }
                        """
                    )
                ],
                name: "Unsafe"
            )
        }
    }

    @Test("Rejects duplicate canonical source paths")
    func rejectsDuplicateSourcePaths() {
        #expect {
            try GravityScriptPlugin(
                sources: [
                    GravityScriptSource(path: "Shared/../Main.ada", source: ""),
                    GravityScriptSource(path: "Main.ada", source: "")
                ],
                name: "Duplicate"
            )
        } throws: { error in
            (error as? GravityScriptError) == .duplicateSourcePath("Main.ada")
        }
    }

    @Test("Preserves the imported source identity in compiler diagnostics")
    func preservesImportedSourceIdentity() {
        #expect {
            try GravityScriptPlugin(
                sources: [
                    GravityScriptSource(
                        path: "Main.ada",
                        source: """
                        import { broken } from "./Shared/Broken";

                        @system
                        class DiagnosticSystem {
                            func update(context) {}
                        }
                        """
                    ),
                    GravityScriptSource(path: "Shared/Broken.ada", source: "func broken( {")
                ],
                name: "Diagnostics"
            )
        } throws: { error in
            guard let scriptError = error as? GravityScriptError,
                  case .compilation(let diagnostics) = scriptError else { return false }
            return diagnostics.contains { $0.hasPrefix("Shared/Broken.ada:") }
        }
    }

    @Test("Rejects namespace imports until namespace isolation is implemented")
    func rejectsNamespaceImports() {
        #expect(throws: GravityScriptError.self) {
            try GravityScriptPlugin(
                sources: [
                    GravityScriptSource(
                        path: "Main.ada",
                        source: """
                        import * as Shared from "./Shared";

                        @system
                        class NamespaceSystem {
                            func update(context) {}
                        }
                        """
                    ),
                    GravityScriptSource(path: "Shared.ada", source: "func helper() {}")
                ],
                name: "Namespace"
            )
        }
    }

    private static let multiFileSources = [
        GravityScriptSource(
            path: "Shared/Steps.ada",
            source: """
            func importedStep() {
                return 3;
            }
            """
        ),
        GravityScriptSource(
            path: "Systems/Movement.ada",
            source: """
            import {
                importedStep
            } from "../Shared/Steps";

            @system(id: "module.movement")
            class ModuleMovementSystem {
                @query(ModulePosition)
                var entities;

                func update(context) {
                    for (var entity in entities) {
                        entity.modulePosition.value += importedStep();
                    }
                }
            }
            """
        ),
        GravityScriptSource(
            path: "Systems/Counter.ada",
            source: """
            @system(id: "module.counter")
            class ModuleCounterSystem {
                @query(ModuleCounter)
                var entities;

                func update(context) {
                    for (var entity in entities) {
                        entity.moduleCounter.value += 2;
                    }
                }
            }
            """
        ),
        GravityScriptSource(path: "Unused/Broken.ada", source: "func broken( {")
    ]
}

@Component
private struct ModulePosition {
    var value: Double
}

@Component
private struct ModuleCounter {
    var value: Double
}

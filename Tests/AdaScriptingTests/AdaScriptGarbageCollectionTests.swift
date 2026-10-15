import AdaApp
import AdaECS
import AdaInput
import AdaScripting
import Testing

@MainActor
@Suite(.serialized)
struct AdaScriptGarbageCollectionTests {
    @Test
    func callbackBindingsSurviveFrequentCollection() async throws {
        CollectionProbe.registerComponent()
        let plugin = try AdaScriptPlugin(source: """
        var tick = 0;
        @system(id: "collection-probe")
        class CollectionSystem {
            @query(CollectionProbe) var probes;
            @query(CollectionProbe) var otherProbes;
            @res var input: Input;
            func update(context) {
                tick += 1;
                // Vary allocation pressure so collections cross different binding boundaries.
                for (var index in 0..<(tick % 31)) { var temporary = [index, tick]; }
                for (var row in probes) {
                    row.collectionProbe.value += 1;
                    // Native System getters temporarily suspend collection themselves.
                    row.collectionProbe.collectorEnabled = System.gcEnabled >= 0;
                    row.collectionProbe.inputAvailable = input.available();
                }
                for (var row in otherProbes) { row.collectionProbe.value += 1; }
            }
        }
        """, name: "CollectionProbe")
        let world = World()
        let app = AppWorlds(main: world)
        InputPlugin(actions: []).setup(in: app)
        plugin.setup(in: app)
        let entity = world.spawn { CollectionProbe() }
        for _ in 0..<50_000 {
            await world.runScheduler(.update)
        }
        let result = try #require(world.get(CollectionProbe.self, from: entity.id))
        #expect(result.value == 100_000)
        #expect(result.collectorEnabled)
        #expect(result.inputAvailable)
        #expect(plugin.diagnostics.isEmpty)
    }
}

@Component
private struct CollectionProbe {
    var value: Int = 0
    var collectorEnabled: Bool = false
    var inputAvailable: Bool = false
}

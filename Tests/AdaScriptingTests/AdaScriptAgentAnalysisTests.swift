import AdaScriptCompilerCore
import Testing

@Suite("AdaScript agent analysis")
struct AdaScriptAgentAnalysisTests {
    @Test("Navigation query fields have useful types for analysis and completion")
    func navigationFields() {
        let analysis = AdaScriptAnalyzer.analyze(source: """
            @system class Robots {
                @query(NavigationAgent3DComponent, NavigationTarget3DComponent) var robots;
                func update(context) {
                    for (var row in robots) {
                        var state: String = row.navigationAgent3DComponent.state;
                        var arrived: Bool = row.navigationAgent3DComponent.hasArrived;
                        row.navigationTarget3DComponent.destination = [8.0, 0.0, 4.0];
                        row.navigationTarget3DComponent.destination = null;
                    }
                }
            }
            """)
        #expect(analysis.typeIssues.isEmpty)
    }

    @Test("Query and list for-in variables retain their element types")
    func loopBindings() {
        let analysis = AdaScriptAnalyzer.analyze(source: """
        @system class Movement {
            @query(Transform) var players;
            func update(context) {
                for (var player in players) { var entityID: Int = player.id; }
                var numbers = [1, 2, 3];
                for (var number in numbers) { var copy: Int = number; }
            }
        }
        """)
        #expect(analysis.inferredTypes["player"] == .queryRow(["Transform"]))
        #expect(analysis.inferredTypes["number"] == .int)
        #expect(analysis.typeIssues.isEmpty)
    }

    @Test("Invalid runtime transform member access is diagnosed")
    func transformRepresentation() {
        let source = """
        @system class Movement {
            @query(Transform) var players;
            func update(context) {
                for (var player in players) { player.transform.position.x = 1.0; }
            }
        }
        """
        let analysis = AdaScriptAnalyzer.analyze(source: source)
        #expect(analysis.typeIssues.contains { $0.message.contains("has no member 'x'") })
    }
}

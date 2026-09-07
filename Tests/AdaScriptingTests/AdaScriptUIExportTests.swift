import AdaScriptCompilerCore
@testable import AdaRender
@testable import AdaScripting
@testable import AdaUI
import Foundation
import Math
import Testing

@MainActor @Suite(.serialized)
struct AdaScriptUIExportTests {
    init() throws {
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            try RenderEngine.setupRenderEngine()
        }
    }

    @Test func exportedPropertyWritesBackThroughBindingAfterAnAction() throws {
        let sources = [AdaScriptSource(path: "Export.ada", source: """
        @view
        class ExportView {
            var title = "Initial";
            func body() {
                Button(title) { title = "Updated"; }.accessibilityIdentifier("export.button");
            }
        }
        """)]
        let export = AdaScriptUIExport(source: "Export.ada", identifier: "ExportView", signature: .init(id: "Game.Export", name: "Export", parameters: [.init("title", type: .string, isBinding: true)]))
        let catalog = try UICatalog.standard.adding(script: export, sources: sources)
        let context = UIBindingContext(values: ["title": .string("External")])
        let session = try UISceneInstance(document: .init(root: .init(type: "Game.Export", arguments: ["title": .init(binding: "title")])), context: context, catalog: catalog)
        let container = UIContainerView(rootView: UISceneView(session: session))
        container.frame = Rect(x: 0, y: 0, width: 300, height: 100)
        container.layoutSubviews()
        _ = try container.uiTapNode(matching: .accessibilityIdentifier("export.button"))
        container.layoutSubviews()
        #expect(context.value("title") == .string("Updated"))
        #expect(context.diagnostics.isEmpty)
    }

    @Test func objectBindingKeepsMapFieldsAfterScriptMutation() throws {
        let sources = [AdaScriptSource(path: "Object.ada", source: """
        @view
        class ObjectView {
            var item = ["name": "Initial", "count": 0];
            func body() {
                Button(item["name"]) { item["count"] = item["count"] + 1; }.accessibilityIdentifier("object.button");
            }
        }
        """)]
        let export = AdaScriptUIExport(source: "Object.ada", identifier: "ObjectView", signature: .init(id: "Game.Object", name: "Object", parameters: [.init("item", type: .object, isBinding: true)]))
        let catalog = try UICatalog.standard.adding(script: export, sources: sources)
        let data = UIBindingContext(values: ["item": .object(["name": .string("Item"), "count": .number(2)])])
        let session = try UISceneInstance(document: .init(root: .init(type: "Game.Object", arguments: ["item": .init(binding: "item")])), context: data, catalog: catalog)
        let container = UIContainerView(rootView: UISceneView(session: session))
        container.frame = Rect(x: 0, y: 0, width: 300, height: 100)
        container.layoutSubviews()
        _ = try container.uiTapNode(matching: .accessibilityIdentifier("object.button"))
        #expect(data.value("item.count") == .number(3))
        #expect(data.value("item.name") == .string("Item"))
        #expect(data.diagnostics.isEmpty)
    }

    @Test func nativeViewUsesHostCatalogAndPreservesModifierOrder() throws {
        var values: [String] = []
        let catalog = try UICatalog.standard.adding(views: [.init(signature: .init(id: "Game.Label", name: "Label", parameters: [.init("text", type: .string)])) { inputs in
            values.append(inputs.string("text")); return AnyView(Text(inputs.string("text")))
        }])
        let sources = [AdaScriptSource(path: "Native.ada", source: """
        @view
        class NativeViewExample {
            func body() { NativeView("Game.Label", text: "Hello").padding(4).background("#ffffff").padding(8); }
        }
        """)]
        let view = try AdaScriptView(sources: sources, identifier: "NativeViewExample", catalog: catalog)
        let container = UIContainerView(rootView: view)
        container.frame = Rect(x: 0, y: 0, width: 300, height: 100)
        container.layoutSubviews()
        #expect(values.contains("Hello"))
    }
}

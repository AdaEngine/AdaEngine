@_spi(AdaEngine) import AdaEngine
import Foundation

extension EditorInspectorSidebar {
    func shaderGraphReferenceField(_ field: EditorInspectorSidebarViewModel.ComponentField) -> some View {
        let identifier = "\(field.typeName).\(field.field.key)"
        let text = viewModel.componentFieldBinding(typeName: field.typeName, field: field.field)
        let assets = viewModel.shaderGraphAssets.filter {
            assetSearchText.isEmpty || $0.reference.localizedCaseInsensitiveContains(assetSearchText)
        }
        return VStack(alignment: .leading, spacing: 6) {
            if field.field.valuePath.first == "graphMaterials", field.field.valuePath.count > 1 {
                Text(L10n.text("Material \(field.field.valuePath[1])")).font(.system(size: 10)).foregroundColor(theme.editorColors.muted)
            }
            Button(action: {
                activeAssetFieldID = activeAssetFieldID == identifier ? nil : identifier
                assetSearchText = ""
            }) {
                Text(verbatim: field.value.isEmpty ? L10n.text("Choose shader graph…") : field.value)
                    .font(.system(size: 11)).frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityIdentifier("AdaEditor.Inspector.ShaderGraph")
            if activeAssetFieldID == identifier {
                TextField(L10n.text("Search shader graphs"), text: Binding(get: { assetSearchText }, set: { assetSearchText = $0 }))
                    .font(.system(size: 11)).frame(height: 28)
                ScrollView {
                    VStack(alignment: .leading, spacing: 5) {
                        Button(L10n.text("None")) { text.wrappedValue = ""; activeAssetFieldID = nil }
                        ForEach(assets) { asset in
                            Button(action: { text.wrappedValue = asset.reference; activeAssetFieldID = nil }) {
                                Text(verbatim: asset.name).font(.system(size: 11))
                            }
                        }
                        if assets.isEmpty {
                            Text(L10n.text("Create a Shader Graph resource in Assets first."))
                                .font(.system(size: 10)).foregroundColor(theme.editorColors.muted)
                        }
                    }
                }.frame(maxHeight: 180)
            }
        }
    }
}

extension EditorViewModel {
    static func shaderGraphAssets(from items: [EditorProjectSidebarViewModel.Item]) -> [EditorInspectorSidebarViewModel.TextureAsset] {
        items.compactMap { item in
            guard !item.isFolder, URL(fileURLWithPath: item.title).pathExtension.lowercased() == "shadergraph",
                let root = item.assetRoot, let reference = assetReference(for: item.relativePath, assetsRoot: root),
                let absolutePath = absoluteFilePath(from: item.id) else { return nil }
            return .init(name: item.title, reference: reference, absolutePath: absolutePath)
        }
    }
}

import Foundation

enum SceneDocumentFormat {
    static let canonicalExtension = "ascn"
    static let supportedExtensions: Set<String> = ["ascn", "scene", "scn"]
    static let defaultScenePath = "Assets/Scenes/Main.ascn"

    static func isSceneFile(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }

    static func defaultSceneYAML(projectName: String) -> String {
        let sceneName = normalizedSceneName(projectName)
        return """
        format: ada.scene
        schemaVersion: 1
        engineVersion: 1.0.0

        scene:
          id: \(UUID().uuidString)
          name: \(sceneName)

        entities:
          - id: root
            name: Root
            enabled: true
            parent:
            components:
              AdaTransform.Transform:
                position: [0, 0, 0]
                rotation: [0, 0, 0, 1]
                scale: [1, 1, 1]

        editor:
          selectedEntity: root
          expandedEntities: [root]
          viewport:
            position: [0, 0]
            zoom: 1
        """
    }

    private static func normalizedSceneName(_ projectName: String) -> String {
        let trimmed = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Main" : trimmed
    }
}

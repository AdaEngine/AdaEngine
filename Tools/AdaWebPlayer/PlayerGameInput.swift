import AdaEngine
@_spi(Internal) import AdaInput
import AdaScriptCompilerCore
import Foundation

/// Bounded agent keyboard input targets the game world, independently of AdaUI
/// viewport focus. Ordinary browser keyboard events retain normal focus routing.
@MainActor
final class PlayerGameInput {
    weak var world: World?

    func send(key: String, down: Bool) throws {
        guard !PlayerBrowserSession.editMode, let world, world.getResource(Input.self) != nil else {
            throw AdaWebPlayerProjectError.invalid("Start Play before sending gameplay input")
        }
        let named: [String: KeyCode] = ["Space": .space, "Enter": .enter, "Escape": .escape,
            "ArrowLeft": .arrowLeft, "ArrowRight": .arrowRight, "ArrowUp": .arrowUp, "ArrowDown": .arrowDown]
        let code: KeyCode?
        if let known = named[key] { code = known }
        else if key.utf8.count == 1, key.range(of: "^[a-zA-Z0-9]$", options: .regularExpression) != nil { code = KeyCode(rawValue: key.lowercased()) }
        else { code = nil }
        guard let code else { throw AdaWebPlayerProjectError.invalid("Unsupported gameplay key") }
        world.getRefResource(Input.self).wrappedValue.receiveEvent(KeyEvent(
            window: RID(), keyCode: code, modifiers: [], status: down ? .down : .up,
            time: Float(Time.absolute), isRepeated: false
        ))
    }
}

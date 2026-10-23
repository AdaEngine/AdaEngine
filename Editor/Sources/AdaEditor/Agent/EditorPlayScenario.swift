@_spi(AdaEngine) import AdaEngine
import Foundation
import MCP

/// A timed input script for `editor.play.run_scenario`, validated against hard limits.
struct EditorPlayScenario: Equatable {
    enum Limits {
        static let maxDuration = 60.0
        static let maxEvents = 400
        static let maxFrames = 12
        static let maxSnapshots = 40
        static let maxEntitiesPerSnapshot = 25
        static let defaultDimension = 640
        static let maxDimension = 1280
        static let defaultHold = 0.12
        static let maxHold = 2.0
        static let defaultSize = SizeInt(width: 960, height: 540)
        static let maxSurface = 1920
    }

    enum Input: Equatable {
        case key(KeyCode, down: Bool)
        case mouse(MouseButton, down: Bool, x: Float, y: Float)
        case pointer(x: Float, y: Float)
    }

    enum Action: Equatable {
        case input(Input)
        case capture(label: String, camera: String?)
        case snapshot(label: String)
    }

    struct Event: Equatable {
        var time: Double
        var action: Action
    }

    enum Target: String, Equatable {
        /// An isolated runtime next to the editor; never touches the user's Play window.
        case offscreen
        /// The game that is already running in Play.
        case play
    }

    struct Watch: Equatable {
        var entities: [String] = []
        var components: [String] = []
    }

    var events: [Event]
    var duration: Double
    var maxDimension: Int
    var surface: SizeInt
    var target: Target
    var watch: Watch
    /// Start the clock only after the game rendered its first frames. Disable to inspect startup frames.
    var warmUp = true

    var frameCount: Int { events.filter { if case .capture = $0.action { true } else { false } }.count }
    var snapshotCount: Int { events.filter { if case .snapshot = $0.action { true } else { false } }.count }
}

struct EditorPlayScenarioError: LocalizedError, Equatable {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

extension EditorPlayScenario {
    /// Parses `steps`, `duration`, `watch`, `maxDimension`, `width`, `height` and `target` tool arguments.
    static func parse(_ arguments: [String: Value]) throws -> EditorPlayScenario {
        guard let steps = arguments["steps"]?.arrayValue, !steps.isEmpty else {
            throw EditorPlayScenarioError("steps must be a non-empty array such as [{\"t\":0.5,\"key\":\"space\",\"tap\":true},{\"t\":1,\"capture\":\"after-flap\"}].")
        }
        var events: [Event] = []
        for (index, step) in steps.enumerated() {
            try events.append(contentsOf: parseStep(step, index: index))
            if events.count > Limits.maxEvents {
                throw EditorPlayScenarioError("A scenario may contain at most \(Limits.maxEvents) events after expanding taps.")
            }
        }
        // Stable order keeps same-time input before the capture/snapshot written after it.
        events = events.enumerated().sorted { lhs, rhs in
            lhs.element.time == rhs.element.time ? lhs.offset < rhs.offset : lhs.element.time < rhs.element.time
        }.map(\.element)

        let scenario = EditorPlayScenario(
            events: events,
            duration: try parseDuration(arguments, events: events),
            maxDimension: try parseInt(arguments["maxDimension"], name: "maxDimension", range: 64...Limits.maxDimension) ?? Limits.defaultDimension,
            surface: SizeInt(
                width: try parseInt(arguments["width"], name: "width", range: 160...Limits.maxSurface) ?? Limits.defaultSize.width,
                height: try parseInt(arguments["height"], name: "height", range: 160...Limits.maxSurface) ?? Limits.defaultSize.height
            ),
            target: try parseTarget(arguments["target"]),
            watch: try parseWatch(arguments["watch"]),
            warmUp: arguments["warmup"]?.boolValue ?? true
        )
        guard scenario.frameCount <= Limits.maxFrames else {
            throw EditorPlayScenarioError("A scenario may capture at most \(Limits.maxFrames) frames.")
        }
        guard scenario.snapshotCount <= Limits.maxSnapshots else {
            throw EditorPlayScenarioError("A scenario may take at most \(Limits.maxSnapshots) state snapshots.")
        }
        return scenario
    }

    static func keyCode(named name: String) -> KeyCode? {
        let normalized = name.lowercased()
        let aliases: [String: String] = ["return": "enter", "esc": "escape", "up": "arrowUp", "down": "arrowDown", "left": "arrowLeft", "right": "arrowRight"]
        let wanted = (aliases[normalized] ?? name).lowercased()
        return KeyCode.allCases.first { code in
            code != .none && (String(describing: code).lowercased() == wanted || code.rawValue.lowercased() == wanted)
        }
    }

    private static func parseStep(_ value: Value, index: Int) throws -> [Event] {
        guard let step = value.objectValue else {
            throw EditorPlayScenarioError("steps[\(index)] must be an object.")
        }
        guard let time = number(step["t"]), time.isFinite, time >= 0, time <= Limits.maxDuration else {
            throw EditorPlayScenarioError("steps[\(index)].t must be seconds in 0...\(Int(Limits.maxDuration)).")
        }
        let kinds = ["key", "mouse", "move", "capture", "snapshot"].filter { step[$0] != nil && step[$0] != .null }
        guard kinds.count == 1, let kind = kinds.first else {
            throw EditorPlayScenarioError("steps[\(index)] needs exactly one of key, mouse, move, capture or snapshot.")
        }
        switch kind {
        case "key":
            guard let name = step["key"]?.stringValue, let code = keyCode(named: name) else {
                throw EditorPlayScenarioError("steps[\(index)].key is not a known key name (for example space, r, w, arrowUp).")
            }
            return try buttonEvents(step, index: index, time: time) { .key(code, down: $0) }
        case "mouse":
            guard let name = step["mouse"]?.stringValue, let button = MouseButton.allCases.first(where: { $0 != .none && $0 != .scrollWheel && String(describing: $0) == name }) else {
                throw EditorPlayScenarioError("steps[\(index)].mouse must be left, right or middle.")
            }
            let x = Float(number(step["x"]) ?? 0)
            let y = Float(number(step["y"]) ?? 0)
            return try buttonEvents(step, index: index, time: time) { .mouse(button, down: $0, x: x, y: y) }
        case "move":
            guard let point = step["move"]?.objectValue, let x = number(point["x"]), let y = number(point["y"]) else {
                throw EditorPlayScenarioError("steps[\(index)].move must be {\"x\":number,\"y\":number}.")
            }
            return [Event(time: time, action: .input(.pointer(x: Float(x), y: Float(y))))]
        case "capture":
            let label = try label(step["capture"], index: index, kind: "capture")
            return [Event(time: time, action: .capture(label: label, camera: step["camera"]?.stringValue))]
        default:
            return [Event(time: time, action: .snapshot(label: try label(step["snapshot"], index: index, kind: "snapshot")))]
        }
    }

    private static func buttonEvents(_ step: [String: Value], index: Int, time: Double, make: (Bool) -> Input) throws -> [Event] {
        if step["tap"]?.boolValue == true {
            let hold = number(step["hold"]) ?? Limits.defaultHold
            guard hold.isFinite, hold > 0, hold <= Limits.maxHold else {
                throw EditorPlayScenarioError("steps[\(index)].hold must be in (0, \(Limits.maxHold)] seconds.")
            }
            return [Event(time: time, action: .input(make(true))), Event(time: time + hold, action: .input(make(false)))]
        }
        guard let down = step["down"]?.boolValue else {
            throw EditorPlayScenarioError("steps[\(index)] needs \"down\": true|false or \"tap\": true.")
        }
        return [Event(time: time, action: .input(make(down)))]
    }

    private static func label(_ value: Value?, index: Int, kind: String) throws -> String {
        if let text = value?.stringValue, !text.isEmpty, text.count <= 48 { return sanitized(text) }
        if value?.boolValue == true { return "\(kind)-\(index)" }
        throw EditorPlayScenarioError("steps[\(index)].\(kind) must be a short label string (or true).")
    }

    /// Labels become file names, so keep them to a safe alphabet.
    static func sanitized(_ label: String) -> String {
        let scalars = label.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_" ? Character($0) : "-" }
        return String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    private static func parseDuration(_ arguments: [String: Value], events: [Event]) throws -> Double {
        let last = events.map(\.time).max() ?? 0
        guard let given = arguments["duration"], given != .null else { return min(Limits.maxDuration, last + 0.5) }
        guard let seconds = number(given), seconds.isFinite, seconds > 0, seconds <= Limits.maxDuration else {
            throw EditorPlayScenarioError("duration must be in (0, \(Int(Limits.maxDuration))] seconds.")
        }
        guard seconds >= last else {
            throw EditorPlayScenarioError("duration (\(seconds)s) ends before the last event (\(last)s).")
        }
        return seconds
    }

    private static func parseTarget(_ value: Value?) throws -> Target {
        guard let value, value != .null else { return .offscreen }
        guard let text = value.stringValue, let target = Target(rawValue: text) else {
            throw EditorPlayScenarioError("target must be 'offscreen' (isolated runtime) or 'play' (the running game).")
        }
        return target
    }

    private static func parseWatch(_ value: Value?) throws -> Watch {
        guard let value, value != .null else { return Watch() }
        guard let object = value.objectValue else { throw EditorPlayScenarioError("watch must be an object.") }
        func names(_ key: String) throws -> [String] {
            guard let raw = object[key], raw != .null else { return [] }
            guard let array = raw.arrayValue, array.allSatisfy({ $0.stringValue != nil }) else {
                throw EditorPlayScenarioError("watch.\(key) must be an array of strings.")
            }
            return Array(array.compactMap(\.stringValue).prefix(Limits.maxEntitiesPerSnapshot))
        }
        return Watch(entities: try names("entities"), components: try names("components"))
    }

    private static func parseInt(_ value: Value?, name: String, range: ClosedRange<Int>) throws -> Int? {
        guard let value, value != .null else { return nil }
        guard let number = value.intValue, range.contains(number) else {
            throw EditorPlayScenarioError("\(name) must be an integer in \(range.lowerBound)...\(range.upperBound).")
        }
        return number
    }

    private static func number(_ value: Value?) -> Double? {
        value?.doubleValue ?? value?.intValue.map(Double.init)
    }
}

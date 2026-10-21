/// Portable fragment graph. Editor layout is persisted but excluded from lowered computations.
public struct ShaderGraph: Codable, Hashable, Sendable {
    public static let currentVersion = 1

    public enum Target: String, Codable, Sendable { case sprite, pbrSurface }

    public struct RenderSettings: Codable, Hashable, Sendable {
        public enum Mode: String, Codable, CaseIterable, Sendable { case opaque, mask, blend }
        public var mode: Mode
        public var alphaCutoff: Float
        public var doubleSided: Bool

        public init(mode: Mode = .opaque, alphaCutoff: Float = 0.5, doubleSided: Bool = false) {
            self.mode = mode
            self.alphaCutoff = alphaCutoff
            self.doubleSided = doubleSided
        }
    }

    public enum ValueType: String, Codable, Sendable {
        /// Color components are linear RGBA, distinct from an untyped four-component vector.
        case color
        case float, bool, vector2, vector3, vector4, texture2D

        var componentCount: Int {
            switch self {
            case .float, .bool: 1
            case .vector2: 2
            case .vector3: 3
            case .vector4, .color: 4
            case .texture2D: 0
            }
        }

        var isNumeric: Bool { self != .bool && self != .texture2D }
    }

    public enum Operation: String, Codable, CaseIterable, Sendable {
        case constant, parameter, texture, sampleTexture, uv, spriteTexture, add, multiply, lerp, output
        case time, subtract, divide, power, minimum, maximum, clamp, saturate, oneMinus, sine, cosine, absolute, fraction, floor, step, smoothstep, noise2D
        case combine2, combine3, combine4
        case select
    }

    /// A stable reference to a node's output port. Port identifiers are never localized.
    public struct Link: Codable, Hashable, Sendable {
        public var node: String
        public var port: String

        public init(_ node: String, port: String = "value") {
            self.node = node
            self.port = port
        }
    }

    public struct Node: Codable, Hashable, Sendable {
        public var id: String
        /// Stored as text so an unknown operation can be diagnosed at its node.
        public var kind: String
        public var type: ValueType
        /// Numeric literals/defaults; bool uses exactly one component, 0 or 1.
        public var value: [Float]
        /// Stable exposed-parameter ID, or project resource path for a texture node.
        public var reference: String?
        public var inputs: [String: Link]
        /// Authored labels and texture defaults never become shader identifiers.
        public var label: String?
        public var defaultTexture: String?

        public init(
            id: String,
            operation: Operation,
            type: ValueType = .float,
            value: [Float] = [],
            reference: String? = nil,
            inputs: [String: Link] = [:]
        ) {
            self.id = id
            self.kind = operation.rawValue
            self.type = type
            self.value = value
            self.reference = reference
            self.inputs = inputs
        }
    }

    public struct Position: Codable, Hashable, Sendable {
        public var x: Float
        public var y: Float

        public init(x: Float, y: Float) {
            self.x = x
            self.y = y
        }
    }

    public struct LayoutGroup: Codable, Hashable, Sendable {
        public var title: String
        public var nodes: [String]
        public var tint: Int

        public init(title: String, nodes: [String], tint: Int = 0) {
            self.title = title
            self.nodes = nodes
            self.tint = tint
        }
    }

    public struct LayoutNote: Codable, Hashable, Sendable {
        public var text: String
        public var position: Position

        public init(text: String, position: Position) {
            self.text = text
            self.position = position
        }
    }

    public var version: Int
    public var target: Target
    public var output: String
    public var nodes: [Node]
    public var layout: [String: Position]
    public var renderSettings: RenderSettings
    public var groups: [String: LayoutGroup] = [:]
    public var notes: [String: LayoutNote] = [:]

    public init(target: Target, output: String, nodes: [Node], layout: [String: Position] = [:]) {
        self.version = Self.currentVersion
        self.target = target
        self.output = output
        self.nodes = nodes
        self.layout = layout
        self.renderSettings = .init(mode: target == .sprite ? .blend : .opaque)
    }

    private enum CodingKeys: CodingKey { case version, target, output, nodes, layout, renderSettings, groups, notes }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        guard version == Self.currentVersion else {
            throw ShaderGraphDiagnostic(code: .unsupportedVersion)
        }
        target = try container.decode(Target.self, forKey: .target)
        renderSettings = try container.decodeIfPresent(RenderSettings.self, forKey: .renderSettings) ?? .init(mode: target == .sprite ? .blend : .opaque)
        output = try container.decode(String.self, forKey: .output)
        nodes = try container.decode([Node].self, forKey: .nodes)
        layout = try container.decodeIfPresent([String: Position].self, forKey: .layout) ?? [:]
        groups = try container.decodeIfPresent([String: LayoutGroup].self, forKey: .groups) ?? [:]
        notes = try container.decodeIfPresent([String: LayoutNote].self, forKey: .notes) ?? [:]
    }
}

/// Structured compiler feedback; the editor translates codes at its presentation boundary.
public struct ShaderGraphDiagnostic: Error, Equatable, Sendable {
    public enum Code: String, Sendable {
        case unsupportedVersion, invalidNodeID, duplicateNode, missingOutput, multipleOutputs, unknownOperation
        case invalidLiteral, invalidReference, conflictingParameter, missingInput, unknownInput, missingNode, unknownPort, typeMismatch, cycle
    }

    public let code: Code
    public var nodeID: String?
    public var port: String?
    public var expected: ShaderGraph.ValueType?
    public var actual: ShaderGraph.ValueType?

    public init(code: Code, nodeID: String? = nil, port: String? = nil, expected: ShaderGraph.ValueType? = nil, actual: ShaderGraph.ValueType? = nil) {
        self.code = code
        self.nodeID = nodeID
        self.port = port
        self.expected = expected
        self.actual = actual
    }
}

/// Canonically ordered, reachable computations. This value has no editor or GPU state.
public struct ShaderGraphIR: Hashable, Sendable {
    public struct Input: Hashable, Sendable {
        public enum Conversion: Hashable, Sendable { case identity, scalarBroadcast }
        public let source: ShaderGraph.Link
        public let type: ShaderGraph.ValueType
        public let conversion: Conversion
    }

    public struct Instruction: Hashable, Sendable {
        public let nodeID: String
        public let operation: ShaderGraph.Operation
        /// The output instruction has no value output and therefore no type.
        public let type: ShaderGraph.ValueType?
        public let value: [Float]
        public let reference: String?
        public let inputs: [String: Input]
    }

    public let target: ShaderGraph.Target
    public let output: String
    public let instructions: [Instruction]
}

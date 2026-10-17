import CGravity

/// Host capabilities are borrowed for one synchronous invocation. Implementations
/// must invalidate access to engine data after that invocation returns.
public protocol NativeHostObject: AnyObject {
    func read(_ key: String) throws -> NativeValue?
    func write(_ key: String, value: NativeValue) throws -> Bool
    func call(_ method: String, arguments: [NativeValue]) throws -> NativeValue?
    func next(state: inout UInt64) throws -> NativeValue?
}
/// Operations may opt in only when they contain no callback-scoped capabilities.
/// Their implementations must synchronize all cross-thread state.
public protocol NativeSuspensionSafeHostObject: NativeHostObject, Sendable {}

extension NativeHostObject {
    public func read(_: String) throws -> NativeValue? { nil }
    public func write(_: String, value _: NativeValue) throws -> Bool { false }
    public func call(_: String, arguments _: [NativeValue]) throws -> NativeValue? { nil }
    public func next(state _: inout UInt64) throws -> NativeValue? { nil }
}

public indirect enum NativeValue {
    case null, boolean(Bool), integer(Int64), double(Double), string(String)
    case object(NativeInstance), host(any NativeHostObject), list([NativeValue]), task(NativeTask)

    public init(_ literal: NativeLiteral) throws {
        switch literal {
        case .null: self = .null
        case let .boolean(v): self = .boolean(v)
        case let .integer(v): self = .integer(v)
        case let .double(v): self = .double(v)
        case let .string(v): self = .string(v)
        case let .list(v): self = .list(try v.map(Self.init))
        case .identifier: throw NativeRuntimeError.unsupportedValue
        }
    }
    public var literal: NativeLiteral? {
        switch self {
        case .null: .null
        case let .boolean(v): .boolean(v)
        case let .integer(v): .integer(v)
        case let .double(v): .double(v)
        case let .string(v): .string(v)
        case let .list(v):
            if v.allSatisfy({ $0.literal != nil }) { .list(v.compactMap(\.literal)) } else { nil }
        case .object, .host, .task: nil
        }
    }
}

/// Identity and module ownership are immutable. All native storage access is
/// serialized by the owning NativeModule's lock; the handle never exposes C data.
public final class NativeInstance: @unchecked Sendable {
    let owner: NativeModule
    let raw: gravity_aot_value
    public let typeName: String

    init(owner: NativeModule, raw: gravity_aot_value, typeName: String) {
        self.owner = owner; self.raw = raw; self.typeName = typeName
        owner.registerRoot(self)
    }
}

/// A handle to an arena-owned native coroutine. NativeModule serializes its
/// state and code; callers never access the suspended frame directly.
public final class NativeTask: @unchecked Sendable {
    let owner: NativeModule
    let raw: gravity_aot_value
    init(owner: NativeModule, raw: gravity_aot_value) { self.owner = owner; self.raw = raw; owner.registerRoot(self) }
    public var identifier: UInt { UInt(bitPattern: raw.task) }
}

public enum NativeTaskPoll {
    case pending, completed(NativeValue), cancelled
}

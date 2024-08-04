//
//  UIControl.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 18.06.2024.
//

public final class UIEventAction: Hashable, Identifiable {

    public lazy var id: ObjectIdentifier = {
        ObjectIdentifier(self)
    }()

    let callback: () -> Void

    public init(_ block: @escaping () -> Void) {
        self.callback = block
    }

    public func callAsFunction() {
        self.callback()
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: UIEventAction, rhs: UIEventAction) -> Bool {
        lhs.id == rhs.id
    }
}

open class UIControl: UIView {

    public struct State: OptionSet, Hashable {
        public let rawValue: UInt

        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        /// A Boolean value indicating whether the control is in the enabled state.
        public var isEnabled: Bool {
            !self.contains(.disabled)
        }

        /// A Boolean value indicating whether the control is in the selected state.
        public var isSelected: Bool {
            self.contains(.selected)
        }

        /// A Boolean value indicating whether the control draws a highlight.
        public var isHighlighted: Bool {
            self.contains(.highlighted)
        }

        public static let normal = State(rawValue: 1 << 0)
        public static let disabled = State(rawValue: 1 << 1)
        public static let highlighted = State(rawValue: 1 << 2)
        public static let focused = State(rawValue: 1 << 3)
        public static let selected = State(rawValue: 1 << 4)
    }

    public struct Event: OptionSet, Hashable {
        public let rawValue: UInt

        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        public static let valueChanged = Event(rawValue: 1 << 0)
        public static let touchDown = Event(rawValue: 1 << 1)
        public static let touchUp = Event(rawValue: 1 << 2)
        public static let touchDragInside = Event(rawValue: 1 << 3)
        public static let touchCancel = Event(rawValue: 1 << 4)
    }

    public var state: State = .normal

    public typealias Action = () -> Void

    internal var actions: [Event: Set<UIEventAction>] = [:]

    public func addAction(_ action: UIEventAction, for event: Event) {
        self.actions[event, default: []].insert(action)
    }

    public func removeAction(_ action: UIEventAction, for event: Event) {
        self.actions[event]?.remove(action)
    }

    public func triggerActions(for event: Event) {
        self.actions[event]?.forEach {
            $0.callback()
        }
    }

    open override func onMouseEvent(_ event: MouseEvent) {
        switch event.phase {
        case .began, .changed:
            switch event.button {
            case .none:
                state.insert(.highlighted)
            case .left:
                state.insert(.selected)
            default:
                return
            }
        case .ended, .cancelled:
            state.remove(.selected)
            state.remove(.focused)
            state.remove(.highlighted)
        }
    }
}

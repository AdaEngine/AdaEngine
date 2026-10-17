//
//  TextInputEvent.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 06.02.2026.
//

import AdaUtils
import Synchronization

/// An object that contains information about text input event.
/// This event is generated from software keyboard input (iOS) or IME input.
public struct TextInputEvent: InputEvent {
    /// Invalidated when a native editor connection loses its document/caret.
    /// Queued events retain this token so a later focus change cannot retarget them.
    public final class Session: Hashable, Sendable {
        private let active = Mutex(true)
        public init() {}
        public var isActive: Bool { active.withLock { $0 } }
        public func invalidate() { active.withLock { $0 = false } }
        public static func == (lhs: Session, rhs: Session) -> Bool { lhs === rhs }
        public func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }
    }

    public enum Action: UInt8, Hashable, Sendable {
        /// Text was inserted
        case insert = 0
        /// Backspace/delete was pressed
        case deleteBackward = 1
        /// Replaces the active IME composition, or the selection on its first update.
        case setComposingText = 2
        /// Replaces and commits the active composition without replaying editor shortcuts.
        case commitText = 3
        /// Keeps the visible text and ends the current composition.
        case finishComposingText = 4
        /// Deletes UTF-16 units around the selection (excluding the composing range).
        case deleteSurroundingText = 5
        /// Deletes Unicode scalars around the selection (excluding the composing range).
        case deleteSurroundingTextInCodePoints = 6
        /// Sets a composing range using UTF-16 offsets relative to the current caret.
        case setComposingRegion = 7
        /// Sets the selection using UTF-16 offsets relative to the current caret.
        case setSelection = 8
    }

    public var id: RID = RID()

    /// The text that was entered. Empty for deleteBackward action.
    public let text: String

    /// Optional lifetime of the native connection that produced this event.
    public let session: Session?

    /// IME cursor position relative to the end of inserted text when positive,
    /// or its start when zero/negative, following Android InputConnection semantics.
    public let cursorOffset: Int

    /// Surrounding deletion lengths, or relative UTF-16 endpoints for range actions.
    public let rangeStart: Int
    public let rangeEnd: Int

    /// The action type
    public let action: Action

    /// The window that received the input
    public let window: RID

    /// The timestamp of the event
    public var time: TimeInterval

    public init(
        window: RID,
        text: String,
        action: Action,
        time: TimeInterval,
        session: Session? = nil,
        cursorOffset: Int = 1,
        rangeStart: Int = 0,
        rangeEnd: Int = 0
    ) {
        self.session = session
        self.cursorOffset = cursorOffset
        self.rangeStart = rangeStart
        self.rangeEnd = rangeEnd
        self.text = text
        self.action = action
        self.window = window
        self.time = time
    }
}

//
//  KeyframeAnimationInputBindings.swift
//  AdaScene
//

import AdaECS
import AdaInput

/// Maps key down events (non-repeating) to target animation state names.
@Component
public struct KeyframeAnimationInputBindings: Sendable {

    public var bindings: [KeyframeInputBinding]

    public init(bindings: [KeyframeInputBinding] = []) {
        self.bindings = bindings
    }
}

public struct KeyframeInputBinding: Sendable, Hashable {

    public var keyCode: KeyCode

    public var targetState: String

    public init(keyCode: KeyCode, targetState: String) {
        self.keyCode = keyCode
        self.targetState = targetState
    }
}

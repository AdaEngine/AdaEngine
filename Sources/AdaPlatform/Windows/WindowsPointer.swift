#if os(Windows)
import AdaInput

@_spi(Internal)
public enum WindowsCursorResources {
    public static func identifier(for shape: Input.CursorShape) -> UInt {
        switch shape {
        case .arrow: 32512
        case .iBeam: 32513
        case .wait: 32514
        case .cross: 32515
        case .resizeUp, .resizeDown, .resizeUpDown: 32645
        case .resizeLeft, .resizeRight, .resizeLeftRight: 32644
        case .drag, .drop, .move: 32646
        case .forbidden: 32648
        case .pointingHand: 32649
        case .busy: 32650
        case .help: 32651
        }
    }
}

@_spi(Internal)
public enum WindowsPointerButtons {
    /// MK_* bits belong to the native mouse message, independently of keyboard modifiers.
    public static func button(for flags: UInt) -> MouseButton {
        if flags & 0x0001 != 0 { return .left }
        if flags & 0x0002 != 0 { return .right }
        if flags & 0x0010 != 0 { return .middle }
        return .none
    }
}
#endif

//
//  InputKeyCodes.swift
//  AdaEngine
//
//  Created by v.prusakov on 11/2/21.
//

// swiftlint:disable all

public enum KeyCode: String, Hashable, CaseIterable {
    case none = ""

    case enter = "\r"
    case escape = "\\x1B"
    case backspace = "\\b"
    case tab = "\\t"
    case space = " "
    case exclaim = "!"
    case quoteDouble = "\""
    case hash = "#"
    case percent = "%"
    case dollar = "$"
    case ampersand = "&"
    case quote = "'"
    case leftParen = "("
    case rightParen = ")"
    case asterisk = "*"
    case plus = "+"
    case comma = ","
    case minus = "-"
    case period = "."
    case slash = "/"
    case apostrophe = "§"

    case shift
    case capslock
    case ctrl
    case alt
    case meta // "Command" button for macOS/iOS and "Windows" button for Windows/Linux

    case home
    case pageUp
    case pageDown
    case delete

    case num0 = "0"
    case num1 = "1"
    case num2 = "2"
    case num3 = "3"
    case num4 = "4"
    case num5 = "5"
    case num6 = "6"
    case num7 = "7"
    case num8 = "8"
    case num9 = "9"
    
    case colon = ":"
    case semicolon = ";"
    case less = "<"
    case equals = "="
    case greater = ">"
    case question = "?"
    case at = "@"
    
    case a = "a"
    case b = "b"
    case c = "c"
    case d = "d"
    case e = "e"
    case f = "f"
    case g = "g"
    case h = "h"
    case i = "i"
    case j = "j"
    case k = "k"
    case l = "l"
    case m = "m"
    case n = "n"
    case o = "o"
    case p = "p"
    case q = "q"
    case r = "r"
    case s = "s"
    case t = "t"
    case u = "u"
    case v = "v"
    case w = "w"
    case x = "x"
    case y = "y"
    case z = "z"

    case f1 = "F1"
    case f2 = "F2"
    case f3 = "F3"
    case f4 = "F4"
    case f5 = "F5"
    case f6 = "F6"
    case f7 = "F7"
    case f8 = "F8"
    case f9 = "F9"
    case f10 = "F10"
    case f11 = "F11"
    case f12 = "F12"
    case f13 = "F13"
    case f14 = "F14"
    case f15 = "F15"
    case f16 = "F16"
    case f17 = "F17"
    case f18 = "F18"
    case f19 = "F19"
    case f20 = "F20"

    case volumeDown = "VOLUME_DOWN"
    case volumeUp = "VOLUME_UP"
    case volumeMute = "VOLUME_MUTE"

    case leftBracket = "["
    case rightBracket = "]"
    case backslash = "\\"
    case caret = "^"
    case underscore = "_"
    case backquote = "`"

    case insert = "insert"

    // TODO: (Vlad) Make it more platform specific.
    case arrowDown = "125"
    case arrowUp = "126"
    case arrowLeft = "123"
    case arrowRight = "124"
}

extension KeyCode {
    init?(keyCode: UInt16) {
        self.init(rawValue: "\(keyCode)")
    }
}

public struct KeyModifier: OptionSet, Hashable {
    public let rawValue: UInt8
    
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
    
    public static let capsLock = KeyModifier(rawValue: 1 << 0)
    public static let shift = KeyModifier(rawValue: 1 << 1)
    public static let control = KeyModifier(rawValue: 1 << 2)
    public static let main = KeyModifier(rawValue: 1 << 3)
    public static let alt = KeyModifier(rawValue: 1 << 4)
}

#if os(macOS)

import AppKit

extension KeyModifier {
    init(modifiers: NSEvent.ModifierFlags) {
        var flags: KeyModifier = []
        
        if modifiers.contains(.capsLock) {
            flags.insert(.capsLock)
        }
        
        if modifiers.contains(.command) {
            flags.insert(.main)
        }
        
        if modifiers.contains(.control) {
            flags.insert(.control)
        }
        
        if modifiers.contains(.option) {
            flags.insert(.alt)
        }
        
        if modifiers.contains(.shift) {
            flags.insert(.shift)
        }
        
        self.init(rawValue: flags.rawValue)
    }
}

#endif
///*
//   Skip uppercase letters
// */
//
//
//SDLK_CAPSLOCK = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_CAPSLOCK),
//
//SDLK_F1 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_F1),
//SDLK_F2 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_F2),
//SDLK_F3 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_F3),
//SDLK_F4 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_F4),
//SDLK_F5 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_F5),
//SDLK_F6 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_F6),
//SDLK_F7 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_F7),
//SDLK_F8 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_F8),
//SDLK_F9 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_F9),
//SDLK_F10 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_F10),
//SDLK_F11 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_F11),
//SDLK_F12 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_F12),
//
//SDLK_PRINTSCREEN = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_PRINTSCREEN),
//SDLK_SCROLLLOCK = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_SCROLLLOCK),
//SDLK_PAUSE = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_PAUSE),
//SDLK_INSERT = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_INSERT),
//SDLK_HOME = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_HOME),
//SDLK_PAGEUP = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_PAGEUP),
//SDLK_DELETE = '\x7F',
//SDLK_END = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_END),
//SDLK_PAGEDOWN = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_PAGEDOWN),
//SDLK_RIGHT = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_RIGHT),
//SDLK_LEFT = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_LEFT),
//SDLK_DOWN = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_DOWN),
//SDLK_UP = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_UP),
//
//SDLK_NUMLOCKCLEAR = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_NUMLOCKCLEAR),
//SDLK_KP_DIVIDE = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_DIVIDE),
//SDLK_KP_MULTIPLY = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_MULTIPLY),
//SDLK_KP_MINUS = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_MINUS),
//SDLK_KP_PLUS = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_PLUS),
//SDLK_KP_ENTER = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_ENTER),
//SDLK_KP_1 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_1),
//SDLK_KP_2 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_2),
//SDLK_KP_3 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_3),
//SDLK_KP_4 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_4),
//SDLK_KP_5 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_5),
//SDLK_KP_6 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_6),
//SDLK_KP_7 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_7),
//SDLK_KP_8 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_8),
//SDLK_KP_9 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_9),
//SDLK_KP_0 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_0),
//SDLK_KP_PERIOD = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_PERIOD),
//
//SDLK_APPLICATION = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_APPLICATION),
//SDLK_POWER = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_POWER),
//SDLK_KP_EQUALS = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_EQUALS),
//SDLK_F13 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_F13),
//SDLK_F14 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_F14),
//SDLK_F15 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_F15),
//SDLK_F16 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_F16),
//SDLK_F17 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_F17),
//SDLK_F18 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_F18),
//SDLK_F19 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_F19),
//SDLK_F20 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_F20),
//SDLK_F21 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_F21),
//SDLK_F22 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_F22),
//SDLK_F23 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_F23),
//SDLK_F24 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_F24),
//SDLK_EXECUTE = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_EXECUTE),
//SDLK_HELP = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_HELP),
//SDLK_MENU = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_MENU),
//SDLK_SELECT = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_SELECT),
//SDLK_STOP = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_STOP),
//SDLK_AGAIN = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_AGAIN),
//SDLK_UNDO = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_UNDO),
//SDLK_CUT = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_CUT),
//SDLK_COPY = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_COPY),
//SDLK_PASTE = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_PASTE),
//SDLK_FIND = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_FIND),
//SDLK_MUTE = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_MUTE),
//SDLK_VOLUMEUP = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_VOLUMEUP),
//SDLK_VOLUMEDOWN = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_VOLUMEDOWN),
//SDLK_KP_COMMA = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_COMMA),
//SDLK_KP_EQUALSAS400 =
//    SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_EQUALSAS400),
//
//SDLK_ALTERASE = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_ALTERASE),
//SDLK_SYSREQ = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_SYSREQ),
//SDLK_CANCEL = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_CANCEL),
//SDLK_CLEAR = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_CLEAR),
//SDLK_PRIOR = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_PRIOR),
//SDLK_RETURN2 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_RETURN2),
//SDLK_SEPARATOR = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_SEPARATOR),
//SDLK_OUT = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_OUT),
//SDLK_OPER = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_OPER),
//SDLK_CLEARAGAIN = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_CLEARAGAIN),
//SDLK_CRSEL = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_CRSEL),
//SDLK_EXSEL = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_EXSEL),
//
//SDLK_KP_00 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_00),
//SDLK_KP_000 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_000),
//SDLK_THOUSANDSSEPARATOR =
//    SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_THOUSANDSSEPARATOR),
//SDLK_DECIMALSEPARATOR =
//    SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_DECIMALSEPARATOR),
//SDLK_CURRENCYUNIT = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_CURRENCYUNIT),
//SDLK_CURRENCYSUBUNIT =
//    SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_CURRENCYSUBUNIT),
//SDLK_KP_LEFTPAREN = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_LEFTPAREN),
//SDLK_KP_RIGHTPAREN = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_RIGHTPAREN),
//SDLK_KP_LEFTBRACE = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_LEFTBRACE),
//SDLK_KP_RIGHTBRACE = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_RIGHTBRACE),
//SDLK_KP_TAB = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_TAB),
//SDLK_KP_BACKSPACE = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_BACKSPACE),
//SDLK_KP_A = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_A),
//SDLK_KP_B = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_B),
//SDLK_KP_C = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_C),
//SDLK_KP_D = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_D),
//SDLK_KP_E = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_E),
//SDLK_KP_F = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_F),
//SDLK_KP_XOR = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_XOR),
//SDLK_KP_POWER = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_POWER),
//SDLK_KP_PERCENT = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_PERCENT),
//SDLK_KP_LESS = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_LESS),
//SDLK_KP_GREATER = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_GREATER),
//SDLK_KP_AMPERSAND = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_AMPERSAND),
//SDLK_KP_DBLAMPERSAND =
//    SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_DBLAMPERSAND),
//SDLK_KP_VERTICALBAR =
//    SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_VERTICALBAR),
//SDLK_KP_DBLVERTICALBAR =
//    SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_DBLVERTICALBAR),
//SDLK_KP_COLON = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_COLON),
//SDLK_KP_HASH = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_HASH),
//SDLK_KP_SPACE = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_SPACE),
//SDLK_KP_AT = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_AT),
//SDLK_KP_EXCLAM = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_EXCLAM),
//SDLK_KP_MEMSTORE = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_MEMSTORE),
//SDLK_KP_MEMRECALL = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_MEMRECALL),
//SDLK_KP_MEMCLEAR = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_MEMCLEAR),
//SDLK_KP_MEMADD = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_MEMADD),
//SDLK_KP_MEMSUBTRACT =
//    SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_MEMSUBTRACT),
//SDLK_KP_MEMMULTIPLY =
//    SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_MEMMULTIPLY),
//SDLK_KP_MEMDIVIDE = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_MEMDIVIDE),
//SDLK_KP_PLUSMINUS = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_PLUSMINUS),
//SDLK_KP_CLEAR = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_CLEAR),
//SDLK_KP_CLEARENTRY = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_CLEARENTRY),
//SDLK_KP_BINARY = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_BINARY),
//SDLK_KP_OCTAL = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_OCTAL),
//SDLK_KP_DECIMAL = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_DECIMAL),
//SDLK_KP_HEXADECIMAL =
//    SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KP_HEXADECIMAL),
//
//SDLK_LCTRL = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_LCTRL),
//SDLK_LSHIFT = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_LSHIFT),
//SDLK_LALT = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_LALT),
//SDLK_LGUI = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_LGUI),
//SDLK_RCTRL = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_RCTRL),
//SDLK_RSHIFT = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_RSHIFT),
//SDLK_RALT = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_RALT),
//SDLK_RGUI = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_RGUI),
//
//SDLK_MODE = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_MODE),
//
//SDLK_AUDIONEXT = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_AUDIONEXT),
//SDLK_AUDIOPREV = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_AUDIOPREV),
//SDLK_AUDIOSTOP = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_AUDIOSTOP),
//SDLK_AUDIOPLAY = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_AUDIOPLAY),
//SDLK_AUDIOMUTE = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_AUDIOMUTE),
//SDLK_MEDIASELECT = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_MEDIASELECT),
//SDLK_WWW = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_WWW),
//SDLK_MAIL = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_MAIL),
//SDLK_CALCULATOR = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_CALCULATOR),
//SDLK_COMPUTER = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_COMPUTER),
//SDLK_AC_SEARCH = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_AC_SEARCH),
//SDLK_AC_HOME = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_AC_HOME),
//SDLK_AC_BACK = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_AC_BACK),
//SDLK_AC_FORWARD = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_AC_FORWARD),
//SDLK_AC_STOP = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_AC_STOP),
//SDLK_AC_REFRESH = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_AC_REFRESH),
//SDLK_AC_BOOKMARKS = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_AC_BOOKMARKS),
//
//SDLK_BRIGHTNESSDOWN =
//    SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_BRIGHTNESSDOWN),
//SDLK_BRIGHTNESSUP = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_BRIGHTNESSUP),
//SDLK_DISPLAYSWITCH = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_DISPLAYSWITCH),
//SDLK_KBDILLUMTOGGLE =
//    SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KBDILLUMTOGGLE),
//SDLK_KBDILLUMDOWN = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KBDILLUMDOWN),
//SDLK_KBDILLUMUP = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_KBDILLUMUP),
//SDLK_EJECT = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_EJECT),
//SDLK_SLEEP = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_SLEEP),
//SDLK_APP1 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_APP1),
//SDLK_APP2 = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_APP2),
//
//SDLK_AUDIOREWIND = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_AUDIOREWIND),
//SDLK_AUDIOFASTFORWARD = SDL_SCANCODE_TO_KEYCODE(SDL_SCANCODE_AUDIOFASTFORWARD)

public enum MouseButton: UInt8, Hashable {
    case none
    case left
    case right
    case middle
    
    case scrollWheel
}

// swiftlint:enable all

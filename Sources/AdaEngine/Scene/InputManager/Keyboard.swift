//
//  File.swift
//  
//
//  Created by v.prusakov on 5/1/24.
//

import Foundation

class Keyboard {

    typealias KeyCodeHashMap = [UInt16: KeyCode]
    typealias OSKeyCodeHashMap = [KeyCode: UInt16]

    private(set) var keycodes: KeyCodeHashMap = [:]
    private(set) var keycodesInverse: OSKeyCodeHashMap = [:]

    init() {
        self.initialize(keycodes: &keycodes)

        for (osKey, keyCode) in keycodes {
            keycodesInverse[keyCode] = osKey
        }
    }

    func initialize(keycodes: inout KeyCodeHashMap) {
        fatalErrorMethodNotImplemented()
    }
}

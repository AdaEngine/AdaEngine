//
//  ChangeDetectionable.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 05.12.2025.
//

import AdaUtils

public protocol ChangeDetectionable {
    var changeTick: ChangeDetectionTick { get set }

    var isChanged: Bool { get }

    func setChanged()
}

public extension ChangeDetectionable {
    var isChanged: Bool {
        return self.changeTick.change?.wrappedValue == self.changeTick.currentTick
    }

    func setChanged() {
        unsafe self.changeTick.change?.getPointer().pointee = self.changeTick.currentTick
    }
}

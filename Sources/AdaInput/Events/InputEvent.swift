//
//  InputEvent.swift
//  AdaEngine
//
//  Created by v.prusakov on 7/11/22.
//

import AdaUtils

/// Base class for all input events.
public protocol InputEvent: Hashable, Identifiable, Event, Sendable {
    var id: RID { get }
    var window: RID { get }
    var time: AdaUtils.TimeInterval { get }
}

//
//  Never+AppScene.swift
//  
//
//  Created by v.prusakov on 6/14/22.
//

extension Never: AppScene {
    public var _configuration: _AppSceneConfiguration {
        get { fatalError() }
        // swiftlint:disable:next unused_setter_value
        set { fatalError() }
    }
    
    public var scene: Never { fatalError() }
    
    public func _makeWindow(with configuration: _AppSceneConfiguration) -> Window { fatalError() }
}

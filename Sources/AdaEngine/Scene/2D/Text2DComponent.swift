//
//  Text2DComponent.swift
//  
//
//  Created by v.prusakov on 3/5/23.
//

public struct Text2DComponent: Component {
    public var text: AttributedText
    public var textAlignment: TextAlignment
    public var bounds: Rect
    
    public init(
        text: AttributedText,
        textAlignment: TextAlignment = .center,
        bounds: Rect = Rect(x: 0, y: 0, width: .infinity, height: .infinity)
    ) {
        self.text = text
        self.textAlignment = textAlignment
        self.bounds = bounds
    }
}

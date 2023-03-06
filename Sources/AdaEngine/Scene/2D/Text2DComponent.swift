//
//  Text2DComponent.swift
//  
//
//  Created by v.prusakov on 3/5/23.
//

public struct Text2DComponent: Component {
    public var text: AttributedText
    public var textAlignment: TextAlignment
    public var bounds: Rect?
    
    public init(
        text: AttributedText,
        textAlignment: TextAlignment = .center,
        bounds: Rect? = nil
    ) {
        self.text = text
        self.textAlignment = textAlignment
        self.bounds = bounds
    }
}

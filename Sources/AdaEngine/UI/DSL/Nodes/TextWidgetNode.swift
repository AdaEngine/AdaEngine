//
//  TextWidgetNode.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

class TextWidgetNode: WidgetNode {
    
    var text: String = ""
    var font: Font = .system(size: 17)

    init(text: String, font: Font, content: Text) {
        self.text = text
        self.font = font
        super.init(content: content)
    }
}

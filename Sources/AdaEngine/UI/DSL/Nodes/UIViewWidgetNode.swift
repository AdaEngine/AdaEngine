//
//  UIViewWidgetNode.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

final class UIViewWidgetNode: WidgetNode {
    
    private let makeUIView: () -> UIView
    private let updateUIView: (UIView) -> Void
    
    private var view: UIView?
    
    init(
        makeUIView: @escaping () -> UIView,
        updateUIView: @escaping (UIView) -> Void,
        content: any Widget
    ) {
        self.makeUIView = makeUIView
        self.updateUIView = updateUIView
        
        super.init(content: content)
    }
    
    override func performLayout() {
        precondition(self.view != nil)
        self.updateUIView(self.view!)
    }
    
    override func invalidateContent() {
        self.view = self.makeUIView()
        
        super.invalidateContent()
    }
    
    override func draw(with context: GUIRenderContext) {
        view?.draw(with: context)
    }
}

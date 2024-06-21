//
//  UIWidgetView.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 07.06.2024.
//

public class UIWidgetView<Content: Widget>: UIView {
    
    private let widgetTree: WidgetTree<Content>
    
    public init(rootView: Content) {
        self.widgetTree = WidgetTree(rootView: rootView)
        
        super.init()

        self.widgetTree.rootNode.invalidateContent()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        
        widgetTree.rootNode.frame = self.frame
        widgetTree.rootNode.performLayout()
    }
    
    public required init(frame: Rect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    public override func hitTest(_ point: Point, with event: InputEvent) -> UIView? {
        if let widgetNode = self.widgetTree.rootNode.hitTest(point, with: event) {
            return self
        }
        
        return self
    }
    
    public override func point(inside point: Point, with event: InputEvent) -> Bool {
        return self.widgetTree.rootNode.point(inside: point, with: event)
    }
    
    override public func draw(in rect: Rect, with context: GUIRenderContext) {
        widgetTree.renderGraph(renderContext: context)
    }
}

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
    }
    
    public override func layoutSubviews() {
        widgetTree.invalidate(rect: self.frame)
        
        widgetTree.rootNode._printDebugNode()
    }
    
    public required init(frame: Rect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    public override func hitTest(_ point: Point, with event: InputEvent) -> UIView? {
        if let widgetNode = self.widgetTree.rootNode.hitTest(point, with: event) {
            return self
        }
        
        return nil
    }
    
    public override func point(inside point: Point, with event: InputEvent) -> Bool {
        return self.widgetTree.rootNode.point(inside: point, with: event)
    }
    
    override public func update(_ deltaTime: TimeInterval) async {
        await super.update(deltaTime)
    }
    
    override public func draw(in rect: Rect, with context: GUIRenderContext) {
        widgetTree.renderGraph(renderContext: context)
    }
}

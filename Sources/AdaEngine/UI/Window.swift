//
//  Window.swift
//  
//
//  Created by v.prusakov on 5/29/22.
//

public class Window: View {
    
    public typealias ID = RID
    
    // TODO: Maybe, we should use unique ID without RID
    public var id: ID = RID()
    
    public var title: String {
        get { self.systemWindow?.title ?? "" }
        set { self.systemWindow?.title = newValue }
    }
    
    internal var systemWindow: SystemWindow?
    
    public var windowManager: WindowManager {
        return Application.shared.windowManager
    }
    
    public var shouldDraw: Bool = false
    
    internal var sceneManager: SceneManager
    
    public required init(scene: Scene, frame: Rect) {
        self.sceneManager = SceneManager()
        super.init(frame: frame)
        
        self.backgroundColor = .clear
        self.sceneManager.window = self
        self.sceneManager.presentScene(scene)
        self.windowManager.createWindow(for: self)
    }
    
    public required init(frame: Rect) {
        self.sceneManager = SceneManager()
        super.init(frame: frame)
        
        self.backgroundColor = .clear
        self.sceneManager.window = self
        self.windowManager.createWindow(for: self)
    }
    
    public var isActive: Bool = false
    
    public func showWindow(makeFocused flag: Bool) {
        self.windowManager.showWindow(self, isFocused: flag)
    }
    
    public func close() {
        self.windowManager.closeWindow(self)
    }
    
    // MARK: - Lifecycle
    
    open func windowDidAppear() {
        
    }
    
    open func windowDidDisappear() {
        
    }
}

func fatalErrorMethodNotImplemented(
    functionName: String = #function,
    line: Int = #line,
    file: String = #fileID
) -> Never {
    fatalError("Method \(functionName):\(line) not implemented in \(file).")
}

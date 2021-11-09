//
//  InputManager.swift
//  
//
//  Created by v.prusakov on 11/2/21.
//

public final class Input {
    
    internal static let shared = Input()
    
    public static var horizontal: Bool {
        fatalError("")
    }
    
    public static var vertical: Bool {
        fatalError("")
    }
    
    // MARK: - Public Methods
    
    public static func isKeyPressed(_ keyCode: KeyCode) -> Bool {
        fatalError("")
    }
    
    public static func isKeyPressed(_ keyCode: String) -> Bool {
        fatalError("")
    }
    
    public static func isKeyRelease(_ keyCode: KeyCode) -> Bool {
        fatalError("")
    }
    
    public static func isKeyRelease(_ keyCode: String) -> Bool {
        fatalError("")
    }
    
    public static func isActionPressed(_ action: String) -> Bool {
        fatalError()
    }
    
    public static func isActionRelease(_ action: String) -> Bool {
        fatalError()
    }
    
    // MARK: Internal
    
    func processEvents() {
        
    }
    
}

//
//  MetalView.swift
//  
//
//  Created by v.prusakov on 8/13/21.
//

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)

import MetalKit

public final class MetalView: MTKView {
    
}

#endif

#if os(macOS)

extension MetalView {
    
    public override var acceptsFirstResponder: Bool {
        return true
    }
    
    public override func touchesBegan(with event: NSEvent) {
        
    }
    
    public override func touchesMoved(with event: NSEvent) {
        
    }
    
    public override func touchesEnded(with event: NSEvent) {
        
    }
    
    public override func touchesCancelled(with event: NSEvent) {
        
    }
    
    public override func mouseUp(with event: NSEvent) {
        
    }
    
    public override func mouseDown(with event: NSEvent) {
        
    }
    
    public override func keyUp(with event: NSEvent) {
        guard let keyCode = KeyCode(rawValue: event.charactersIgnoringModifiers ?? "") else {
            return
        }
        
        let modifers = KeyModifier(modifiers: event.modifierFlags)
        
        let keyEvent = Input.KeyEvent(keyCode: keyCode, modifiers: modifers, status: .up, time: TimeInterval(event.timestamp))
        Input.shared.receiveEvent(keyEvent)
    }
    
    public override func keyDown(with event: NSEvent) {
        guard let keyCode = KeyCode(rawValue: event.charactersIgnoringModifiers ?? "") else {
            return
        }
        
        let modifers = KeyModifier(modifiers: event.modifierFlags)
        
        let keyEvent = Input.KeyEvent(keyCode: keyCode, modifiers: modifers, status: .down, time: TimeInterval(event.timestamp))
        Input.shared.receiveEvent(keyEvent)
    }
}

#endif

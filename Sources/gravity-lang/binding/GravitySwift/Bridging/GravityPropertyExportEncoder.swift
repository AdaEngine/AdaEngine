//
//  GravityPropertyExportEncoder.swift
//  
//
//  Created by v.prusakov on 6/4/22.
//

import Foundation
import CGravity

public protocol GravityExportClassEncoderContainer {
    func bind(_ method: MethodDescriptor)
    func bind(_ property: PropertyDescriptor)
}

public final class _GravityExportClassEncoderContainer<T: GSExportable>: GravityExportClassEncoderContainer {
    
    private unowned let descriptor: GravityBridgeClassDescriptor
    
    init(descriptor: GravityBridgeClassDescriptor, type: T.Type) {
        self.descriptor = descriptor
    }
    
    public func bind(_ property: PropertyDescriptor) {
        let propertyPtr = Unmanaged.passRetained(property).toOpaque()
        let clazz = self.descriptor.gClass
        
        let fget = gravity_closure_new(self.descriptor.vm.vmPtr, gravity_function_new_bridged(nil, nil, propertyPtr))
        let fset = property.isReadonly ? nil : fget // we use same closure to set and get, because vm can resolve it for us
        let closure = gravity_closure_new(
            self.descriptor.vm.vmPtr,
            gravity_function_new_special(self.descriptor.vm.vmPtr, nil, UInt16(GRAVITY_BRIDGE_INDEX), fget, fset)
        )
        
        property.name.withCString { ptr in
            gravity_class_bind(
                clazz,
                ptr,
                gravity_value_from_object(closure)
            )
        }
        
        self.descriptor.addProperty(property)
    }
    
    public func bind(_ method: MethodDescriptor) {
        let methodPtr = Unmanaged.passRetained(method).toOpaque()
        let clazz = self.descriptor.gClass
        let closure = gravity_closure_new(self.descriptor.vm.vmPtr, gravity_function_new_bridged(nil, nil, methodPtr))!
        let closureValue = gravity_value_from_object(closure)
        
        if method.isConstrucor {
            let narg = method.argsCount > 0 ? "\(method.argsCount)" : ""
            let name = CLASS_INTERNAL_INIT_NAME + narg
            
            name.withCString { ptr in
                gravity_class_bind(clazz, ptr, closureValue)
            }
            
        } else {
            method.name.withCString { ptr in
                gravity_class_bind(clazz, ptr, closureValue)
            }
        }
        
        self.descriptor.addMethod(method)
    }
}

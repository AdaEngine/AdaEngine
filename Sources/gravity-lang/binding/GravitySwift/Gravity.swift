//
//  File.swift
//  
//
//  Created by v.prusakov on 6/6/22.
//

import CGravity

public enum GravityReturn {
    
    public static func noValue() -> Bool {
        return gravity_return_no_value()
    }
    
    public static func value(_ value: GSValue, rIndex: Int32, vm: GravityVirtualMachine) -> Bool {
        return gravity_return_value(vm.vmPtr, value.value, rIndex)
    }
    
    public static func error(_ errorMessage: String, rIndex: Int32, vm: GravityVirtualMachine) -> Bool {
        return errorMessage.withCString { msg in
            gravity_return_error_for_rindex(vm.vmPtr, rIndex, msg)
        }
    }
    
    public static func error(_ errorMessage: String, vm: GravityVirtualMachine) -> Bool {
        return errorMessage.withCString { msg in
            gravity_return_error(vm.vmPtr, msg)
        }
    }
}

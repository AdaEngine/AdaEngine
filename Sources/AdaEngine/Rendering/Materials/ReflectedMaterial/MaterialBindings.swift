//
//  MaterialBindings.swift
//  
//
//  Created by v.prusakov on 4/2/23.
//

// TODO: Should we use struct here?

@propertyWrapper
public final class Uniform<T: ShaderBindable & ShaderUniformValue>: _ShaderBindProperty, _ShaderUniformProperty {
    
    private var _value: T?
    
    public var wrappedValue: T {
        get {
            guard let value = _value else {
                fatalError("Property being accessed without initialization")
            }
            return value
        }
        set {
            self._value = newValue
            self.delegate?.updateValue(newValue, for: self.propertyName)
        }
    }
    
    weak var delegate: MaterialValueDelegate?
    
    var valueLayout: Int { T.layout() }
    public let binding: Int
    internal var propertyName: String = ""
    
    public init(wrappedValue: T, binding: Int, propertyName: String = "") {
        self._value = wrappedValue
        self.propertyName = propertyName
        self.binding = binding
    }
    
    public init(binding: Int, propertyName: String = "") {
        self._value = nil
        self.propertyName = propertyName
        self.binding = binding
    }
    
    func update() {
        self.delegate?.updateValue(self.wrappedValue, for: self.propertyName)
    }
}

@propertyWrapper
public final class FragmentTexture<T: Texture>: _ShaderBindProperty {
    
    private var _value: T?
    
    public var wrappedValue: T {
        get {
            guard let value = _value else {
                fatalError("Property being accessed without initialization")
            }
            return value
        }
        set {
            self._value = newValue
            
            self.delegate?.updateTextures([newValue], for: self.propertyName, binding: self.binding)
        }
    }
    
    public let binding: Int
    internal var propertyName: String = ""
    
    weak var delegate: MaterialValueDelegate?
    
    public init(wrappedValue: T, binding: Int, propertyName: String = "") {
        self._value = wrappedValue
        self.binding = binding
        self.propertyName = propertyName
    }
    
    public init(binding: Int, propertyName: String = "") {
        self._value = nil
        self.binding = binding
        self.propertyName = propertyName
    }
    
    func update() {
        self.delegate?.updateTextures([self.wrappedValue], for: self.propertyName, binding: self.binding)
    }
}

public protocol ShaderBindable {
    static func layout() -> Int
}

public extension ShaderBindable {
    static func layout() -> Int {
        return MemoryLayout<Self>.stride
    }
}

protocol _ShaderBindProperty: AnyObject {
    var propertyName: String { get set }
    var binding: Int { get }
    
    var delegate: MaterialValueDelegate? { get set }
    
    func update()
}

protocol _ShaderUniformProperty {
    var valueLayout: Int { get }
}

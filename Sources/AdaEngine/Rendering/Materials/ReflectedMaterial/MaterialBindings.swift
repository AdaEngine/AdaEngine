//
//  MaterialBindings.swift
//  AdaEngine
//
//  Created by v.prusakov on 4/2/23.
//

// TODO: Should we use struct here?

/// Property wrapper that specify uniform for using in ``ReflectedMaterial``.
///
/// When you want to update value in shader define `Uniform` property wrapper. That property wrapper will capture your property name and will try to change the same uniform shader value in your material.
///
/// For example, if your shader uniform has property with name `color` and you specify the same name in your ``ReflectedMaterial``, than Uniform will connected to it by default.
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
    
    /// Create a new Uniform property wrapper.
    /// - Parameter binding: The index of uniform bind group.
    /// - Parameter propertyName: Custom shader uniform property name, by default it's empty and will capture real property name.
    public init(wrappedValue: T, binding: Int, propertyName: String = "") {
        self._value = wrappedValue
        self.propertyName = propertyName
        self.binding = binding
    }
    
    /// Create a new Uniform property wrapper.
    /// - Parameter binding: The index of uniform bind group.
    /// - Parameter propertyName: Custom shader uniform property name, by default it's empty and will capture real property name.
    public init(binding: Int, propertyName: String = "") {
        self._value = nil
        self.propertyName = propertyName
        self.binding = binding
    }
    
    func update() {
        self.delegate?.updateValue(self.wrappedValue, for: self.propertyName)
    }
}

/// Property wrapper that pass fragment texture to the ``ReflectedMaterial``.
///
/// You can specify texture for your custom material.
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
    
    /// Create a new texture property wrapper.
    /// - Parameter binding: The index of texture bind group.
    /// - Parameter propertyName: Custom shader texture property name, by default it's empty and will capture real property name.
    public init(wrappedValue: T, binding: Int, propertyName: String = "") {
        self._value = wrappedValue
        self.binding = binding
        self.propertyName = propertyName
    }
    
    /// Create a new texture property wrapper.
    /// - Parameter binding: The index of texture bind group.
    /// - Parameter propertyName: Custom shader texture property name, by default it's empty and will capture real property name.
    public init(binding: Int, propertyName: String = "") {
        self._value = nil
        self.binding = binding
        self.propertyName = propertyName
    }
    
    func update() {
        self.delegate?.updateTextures([self.wrappedValue], for: self.propertyName, binding: self.binding)
    }
}

/// Internal shader bind property that will used for reflection.
protocol _ShaderBindProperty: AnyObject {
    
    /// Contains shader property name.
    var propertyName: String { get set }
    
    /// Contains bind group for current property wrapper.
    /// Used for matching property wrapper and shader bind.
    var binding: Int { get }
    
    /// Contains delegate which will recieve updates of current property wrapper.
    var delegate: MaterialValueDelegate? { get set }
    
    /// Update property wrapper. Should be called once when delegate connected to pass stored value to delegate.
    func update()
}

protocol _ShaderUniformProperty {
    var valueLayout: Int { get }
}

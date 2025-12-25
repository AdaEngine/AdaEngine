//
//  CustomMaterial.swift
//  AdaEngine
//
//  Created by v.prusakov on 4/2/23.
//

import AdaAssets
import AdaUtils
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

protocol MaterialValueDelegate: AnyObject {
    func updateValue(_ value: ShaderUniformValue, for name: String)
    func updateTextures(_ textures: [Texture], for name: String, binding: Int)
}

/// This material supports user declared materials.
///
/// It's very powerful tool for creating your own materials using power of Swift.
/// You can declare any materials and describe what kind of values can be used in your shader.
/// Like example, we can define our custom canvas material.
///
/// ```swift
/// struct MyCanvasMaterial: CanvasMaterial {
///
///     // Bind color with u_Color uniform value in shader
///     @Uniform(binding: 0, propertyName: "u_Color")
///     var color: Color = .blue
///
///     // Path to glsl shader source
///     static func fragment() throws -> ShaderSource {
///         try ResourceLoader.loadSync("PATH_TO_FRAGMENT_SHADER.glsl")
///     }
/// }
/// ```
///
/// After that, we should write our own fragment shader code:
///
/// ```c++
/// #version 330 core
/// #pragma stage : frag // Declare that this code can be used for fragment shading
///
/// #include <AdaEngine/CanvasMaterial.frag> // Include basic canvas header code for you shader
///
/// // Declare you material uniform
/// layout (std140, binding = 2) uniform CustomMaterial {
///     vec4 u_Color; // This property will be changed from MyCanvasMaterial
/// };
///
/// [[main]]
/// void my_material_fragment()
/// {
///     COLOR = u_Color; // Set material color to output color value.
/// }
/// ```
///
/// And than, you can pass our new material to anywhere you want. Also CustomMaterial supports @propertyWrapper magic
///
/// ```swift
/// let mesh = Mesh()
/// let customMaterial = CustomMaterial(MyCanvasMaterial())
/// let meshComponent = Mesh2D(mesh: mesh, materials: [customMaterial])
///
/// entity.components += meshComponent
///
/// // -- or --
/// let mesh = Mesh()
/// @CustomMaterial var customMaterial = MyCanvasMaterial()
///
/// // Send custom material using $ symbol. We should pass CustomMaterial<MyCanvasMaterial> instance
/// let meshComponent = Mesh2D(mesh: mesh, materials: [$customMaterial])
///
/// entity.components += meshComponent
/// ```
///
/// You can update material values with two different ways with reflection or string literals.
/// ```swift
/// let customMaterial = CustomMaterial(MyCanvasMaterial())
///
/// // Pass new value into material using reflection.
/// customMaterial.color = .blue
///
/// // Pass new value into material using string literals
/// // In this case we should think about correct name of uniform member.
/// customMaterial.setValue(Color.blue, for: "u_Color")
/// ```
///
@propertyWrapper
@dynamicMemberLookup
public final class CustomMaterial<T: ReflectedMaterial>: Material, MaterialValueDelegate, @unchecked Sendable {

    public var wrappedValue: T {
        get {
            return material
        }

        set {
            self.material = newValue
        }
    }

    public var projectedValue: CustomMaterial<T> {
        return self
    }

    /// User material that can be updated.
    public var material: T {
        didSet {
            self.reflectMaterial(from: self.material)
        }
    }

    /// Contains all bindable properties founded in passed ``ReflectedMaterial``.
    private var bindableValues: [_ShaderBindProperty] = []

    public convenience init(wrappedValue: T) {
        self.init(wrappedValue)
    }

    /// Create a new CustomMaterial instance from user ``ReflectedMaterial``.
    public init(_ material: T) {
        self.material = material
        
        let shaderSource = ShaderSource()
        
        do {
            let vertexShaderSource = try T.vertexShader()
            let fragmentShaderSource = try T.fragmentShader()

            assert(vertexShaderSource.asset.getSource(for: .vertex) != nil, "Failed to load vertex data")
            assert(fragmentShaderSource.asset.getSource(for: .fragment) != nil, "Failed to load fragment data")
            
            shaderSource.setSource(vertexShaderSource.asset.getSource(for: .vertex)!, for: .vertex)
            shaderSource.setSource(fragmentShaderSource.asset.getSource(for: .fragment)!, for: .fragment)
            
            shaderSource.includeSearchPaths.append(contentsOf: vertexShaderSource.asset.includeSearchPaths)
            shaderSource.includeSearchPaths.append(contentsOf: fragmentShaderSource.asset.includeSearchPaths)
        } catch {
            assertionFailure("[CustomMaterial] \(error.localizedDescription)")
        }
        
        super.init(shaderSource: shaderSource)
        self.reflectMaterial(from: material)
    }
    
    public required init(from decoder: AssetDecoder) throws {
        fatalError("init(asset:) has not been implemented")
    }
    
    public subscript<Value>(dynamicMember keyPath: WritableKeyPath<T, Value>) -> Value {
        get {
            return self.material[keyPath: keyPath]
        }
        
        set {
            self.material[keyPath: keyPath] = newValue
        }
    }
    
    // MARK: - Mesh
    
    public override func collectDefines(for vertexDescriptor: VertexDescriptor, keys: Set<String>) -> [ShaderDefine] {
        return T.configureShaderDefines(keys: keys, vertexDescriptor: vertexDescriptor)
    }
    
    public override func configureRenderPipeline(
        for vertexDescriptor: VertexDescriptor,
        keys: Set<String>,
        shaderModule: ShaderModule
    ) -> RenderPipelineDescriptor? {
        do {
            let pipeline = try T.configurePipeline(
                keys: keys,
                vertex: shaderModule.getShader(for: .vertex)!,
                fragment: shaderModule.getShader(for: .fragment)!,
                vertexDescriptor: vertexDescriptor
            )
            
            return pipeline
        } catch {
            assertionFailure("[CustomMaterial] \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Find and link shader bind properties.
    func reflectMaterial(from material: T) {
        self.bindableValues.removeAll()

        let reflection = Mirror(reflecting: material)
        
        for child in reflection.children {
            guard let bindProperty = child.value as? _ShaderBindProperty else {
                continue
            }
            
            if bindProperty.propertyName.isEmpty {
                // Get the propertyName of the property. By syntax, the property name is
                // in the form: "_name". Dropping the "_" -> "name"
                let propertyName = String((child.label ?? "").dropFirst())
                bindProperty.propertyName = propertyName
            }
            
            // For update buffers
            bindProperty.delegate = self
            
            self.bindableValues.append(bindProperty)
        }
    }
    
    public override func update() {
        self.bindableValues.forEach {
            $0.update()
        }
    }
    
    // MARK: Delegate
    
    func updateValue(_ value: ShaderUniformValue, for name: String) {
        self.setValue(value, for: name)
    }
    
    func updateTextures(_ textures: [Texture], for name: String, binding: Int) {
        self.setResources(textures, for: name)
    }
}

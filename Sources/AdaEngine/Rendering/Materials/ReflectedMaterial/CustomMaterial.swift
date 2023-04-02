//
//  CustomMaterial.swift
//  
//
//  Created by v.prusakov on 4/2/23.
//

protocol MaterialValueDelegate: AnyObject {
    func updateValue(_ value: ShaderUniformValue, for name: String)
    func updateTextures(_ textures: [Texture], for name: String, binding: Int)
}

@dynamicMemberLookup
public final class CustomMaterial<T: ReflectedMaterial>: Material, MaterialValueDelegate {
    
    public var material: T
    
    private var bindableValues: [_ShaderBindProperty] = []
    
    public init(_ material: T) {
        self.material = material
        
        let shaderSource = ShaderSource()
        
        do {
            let vertexShaderSource = try T.vertexShader()
            let fragmentShaderSource = try T.fragmentShader()
            
            assert(vertexShaderSource.getSource(for: .vertex) != nil, "Failed to load vertex data")
            assert(fragmentShaderSource.getSource(for: .fragment) != nil, "Failed to load fragment data")
            
            shaderSource.setSource(vertexShaderSource.getSource(for: .vertex)!, for: .vertex)
            shaderSource.setSource(fragmentShaderSource.getSource(for: .fragment)!, for: .fragment)
            
            shaderSource.includeSearchPaths.append(contentsOf: vertexShaderSource.includeSearchPaths)
            shaderSource.includeSearchPaths.append(contentsOf: fragmentShaderSource.includeSearchPaths)
            
        } catch {
            assertionFailure("[CustomMaterial] \(error.localizedDescription)")
        }
        
        super.init(shaderSource: shaderSource)
        self.reflectMaterial(from: material)
    }
    
    public required init(asset decoder: AssetDecoder) throws {
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
    
    override func collectDefines(for vertexDescriptor: VertexDescriptor, keys: Set<String>) -> [ShaderDefine] {
        return T.configureShaderDefines(keys: keys, vertexDescriptor: vertexDescriptor)
    }
    
    override func configureRenderPipeline(
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
    
    func reflectMaterial(from material: T) {
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
    
    override func update() {
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

//
//  ShaderCompiler.swift
//  
//
//  Created by v.prusakov on 8/22/22.
//

import Foundation
//import SPIRV_Cross
//import glslang
//
//public protocol ShaderCompiler {
//    init(url: URL, disableOptimization: Bool) throws
//    func compile() throws -> String
//}
//
//#if METAL
//
//class MetalCompiler: ShaderCompiler {
//    
//    var context: spvc_context
//    var compiler: spvc_compiler!
//    
//    required init(url: URL, disableOptimization: Bool) throws {
//        var context: spvc_context?
//        var compiler: spvc_compiler?
//        var result = spvc_context_create(&context)
//        
//        guard let context = context, result == SPVC_SUCCESS else {
//            fatalError("Can't create spvc context, with result \(result)")
//        }
//        
//        self.context = context
//        
//        // should be spv binary here
//        var ir: spvc_parsed_ir?
//        let data = try! Data(contentsOf: url)
//        
//        let _ = data.withUnsafeBytes { bytes -> spvc_result in
//            let spv = bytes.bindMemory(to: SpvId.self)
//            return spvc_context_parse_spirv(context, spv.baseAddress, spv.count, &ir)
//        }
//        
//        if result != SPVC_SUCCESS {
//            fatalError("Can't create parsed ir with result \(result)")
//        }
//        
//        result = spvc_context_create_compiler(context, SPVC_BACKEND_MSL, ir, SPVC_CAPTURE_MODE_TAKE_OWNERSHIP, &compiler)
//        
//        if result != SPVC_SUCCESS {
//            fatalError("Can't create compiler with result \(result)")
//        }
//    }
//    
//    deinit {
//        spvc_context_destroy(self.context)
//    }
//    
//    func compile() throws -> String {
////        var binding: spvc_msl_resource_binding!
////        spvc_msl_resource_binding_init(&binding)
//        
//        var source: UnsafePointer<CChar>?
//        var result = spvc_compiler_compile(self.compiler, &source)
//        
//        guard let source = source, result == SPVC_SUCCESS else {
//            fatalError("Can't compile sources")
//        }
//        
//        return String(cString: source)
//    }
//}
//
//#endif

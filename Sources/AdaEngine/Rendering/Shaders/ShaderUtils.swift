//
//  ShaderUtils.swift
//  
//
//  Created by v.prusakov on 3/13/23.
//

import Foundation

enum ShaderUtils {
    
    enum CommentState {
        case singleLineComment
        case multiLineComment
        case notAComment
        case slash
        case star
    }
    
    enum ProcessingError: LocalizedError {
        case noMacroSymbols
        case invalidDeclaration(String)
        case noStageFound
        
        var errorDescription: String? {
            switch self {
            case .noMacroSymbols:
                return "[ShaderCompiler] Macro symbol `#` not found."
            case .invalidDeclaration(let message):
                return "[ShaderCompiler] Invalid declaration: \(message)."
            case .noStageFound:
                return "[ShaderCompiler] Stages not found."
            }
        }
    }
    
    static func preprocessShader(source: String) throws -> [ShaderStage: String] {
        let finalSource = ShaderUtils.removeComments(from: source)
        
        var shaderSources: [ShaderStage : String] = [:]
        var stagePositions: [(ShaderStage, String.Index)] = []
        
        guard var pointer = finalSource.firstIndex(of: "#") else {
            throw ProcessingError.noMacroSymbols
        }
        
        var startStagePosition = pointer
        
        while pointer < finalSource.endIndex {
            let newSource = finalSource[pointer..<finalSource.endIndex]
            
            guard let endOfLine = newSource.firstIndex(where: { $0.isNewline }) else {
                break
            }
            
            let regular = try NSRegularExpression(pattern: "((^\\W|^\\w+)|(\\w+)|[:()])", options: 0)
            let matches = regular.matches(
                in: finalSource,
                options: 0,
                range: NSRange(pointer..<endOfLine, in: finalSource)
            )
            
            let firstToken = finalSource.getSubstring(from: matches[1].range)
            
            switch firstToken {
            case "version":
                startStagePosition = finalSource.getSubstring(from: matches[0].range).startIndex
            case "pragma":
                if finalSource.getSubstring(from: matches[2].range) == "stage" {
                    if finalSource.getSubstring(from: matches[3].range) == ":" {
                        let stageString = finalSource.getSubstring(from: matches[4].range)
                        let stage = self.shaderStage(from: String(stageString))
                        stagePositions.append((stage, startStagePosition))
                    } else {
                        throw ProcessingError.invalidDeclaration("Invalid stage declaration. Use `pragma stage : YOUR_STAGE`")
                    }
                }
            default:
                break
            }
            
            guard let newPosition = newSource[endOfLine...].firstIndex(of: "#") else {
                break
            }
            
            pointer = newPosition
        }
        
        if stagePositions.isEmpty {
            throw ProcessingError.noStageFound
        }
        
        for index in 0..<stagePositions.count {
            let (currentStage, currentStringIndex) = stagePositions[index]
            
            if stagePositions.indices.contains(index + 1) {
                let (_, nextStringIndex) = stagePositions[index + 1]
                
                let stageSource = finalSource[currentStringIndex..<nextStringIndex]
                shaderSources[currentStage] = String(stageSource)
            } else {
                let stageSource = finalSource[currentStringIndex..<finalSource.endIndex]
                shaderSources[currentStage] = String(stageSource)
            }
        }
        
        return shaderSources
    }
    
    // swiftlint:disable:next cyclomatic_complexity
    static func removeComments(from string: String) -> String {
        var state: CommentState = .notAComment
        
        let newString = string.filter { char in
            switch state {
            case .star:
                if char == "/" {
                    state = .notAComment
                } else {
                    state = .multiLineComment
                }
            case .notAComment:
                if char == "/" {
                    state = .slash
                } else {
                    return true
                }
            case .singleLineComment:
                if char.isNewline {
                    state = .notAComment
                    return true
                }
            case .multiLineComment:
                if char == "*" {
                    state = .star
                } else if char.isNewline {
                    return true
                }
            case .slash:
                if char == "/" {
                    state = .singleLineComment
                } else if char == "*" {
                    state = .multiLineComment
                } else {
                    state = .notAComment
                    return true
                }
            }
            
            return false
        }
        
        return newString
    }
    
    static func shaderStage(from string: String) -> ShaderStage {
        switch string {
        case "vert":
            return .vertex
        case "frag":
            return .fragment
        case "comp":
            return .compute
        default:
            return .max
        }
    }
    
    static func shaderLang(from fileExt: String) -> ShaderLanguage {
        switch fileExt {
        case "vert", "frag", "glsl":
            return .glsl
        case "hlsl":
            return .hlsl
        default:
            return .glsl
        }
    }
}

extension String {
    func getSubstring(from nsRange: NSRange) -> Substring {
        let start = self.index(self.startIndex, offsetBy: nsRange.lowerBound)
        let end = self.index(self.startIndex, offsetBy: nsRange.upperBound)
        
        return self[start..<end]
    }
}

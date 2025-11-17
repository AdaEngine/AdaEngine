//
//  ImageLoaderStrategy.swift
//  AdaEngine
//
//  Created by v.prusakov on 6/28/22.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// An interface that describe how to build an ``Image`` object from bytes.
protocol ImageLoaderStrategy: Sendable {
    
    func canDecodeImage(with fileExtensions: String) -> Bool
    
    func decodeImage(from data: Data) throws -> Image
}

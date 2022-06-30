//
//  ImageLoaderStrategy.swift
//  
//
//  Created by v.prusakov on 6/28/22.
//

import Foundation

protocol ImageLoaderStrategy {
    
    func canDecodeImage(with fileExtensions: String) -> Bool
    
    func decodeImage(from data: Data) throws -> Image
}

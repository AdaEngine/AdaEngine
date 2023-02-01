//
//  PluginHelp.swift
//  
//
//  Created by v.prusakov on 5/27/22.
//

import PackagePlugin

enum PluginHelp {
    static var helpOverview: String = """
    OVERVIEW: Compile GLSL shaders to spir-v binaries available for Vulkan SDK.
    
    USAGE: swift package [<package-manager-options>] spirv [<plugin-options>]
    
    PACKAGE MANAGER OPTIONS:
      --allow-writing-to-package-directory
                                    Allow the plugin to write to the package directory.
      --allow-writing-to-directory <directory-path>
                                    Allow the plugin to write to an additional directory
    
    PLUGIN OPTIONS:
      --input-files  <urls>         GLSL files
      --input-folder <url>          Folder path to GLSL files.
      --output <url>                Output path for spri-v binaries (Required)
    
      --verbose                     Verbose mode.
    
    """
}

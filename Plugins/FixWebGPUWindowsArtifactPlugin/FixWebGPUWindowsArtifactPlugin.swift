//
//  FixWebGPUWindowsArtifactPlugin.swift
//  AdaEngine
//
//  Workaround: SwiftPM on Windows expects static libraries in artifact bundles
//  to be named lib*.lib. The swift-webgpu artifact provides webgpu_dawn.lib.
//  This plugin copies it to libwebgpu_dawn.lib and patches info.json so the build can proceed.
//

import Foundation
import PackagePlugin

@main
struct FixWebGPUWindowsArtifactPlugin: CommandPlugin {

    func performCommand(context: PluginContext, arguments: [String]) async throws {
        #if !os(Windows)
        Diagnostics.remark("FixWebGPUWindowsArtifact: not Windows, skipping")
        return
        #endif

        let packageDir = context.package.directory.string
        let bundleDir = "\(packageDir)/.build/artifacts/swift-webgpu/DawnLib/dawn_webgpu.artifactbundle"
        let winDir = "\(bundleDir)/windows_x86_64_release"
        let artifactLib = "\(winDir)/webgpu_dawn.lib"
        let libLib = "\(winDir)/libwebgpu_dawn.lib"
        let infoPath = "\(bundleDir)/info.json"
        let fm = FileManager.default

        guard fm.fileExists(atPath: artifactLib) else {
            Diagnostics.remark("FixWebGPUWindowsArtifact: webgpu_dawn.lib not found, skipping")
            return
        }
        if !fm.fileExists(atPath: libLib) {
            try fm.copyItem(atPath: artifactLib, toPath: libLib)
            Diagnostics.remark("FixWebGPUWindowsArtifact: copied webgpu_dawn.lib -> libwebgpu_dawn.lib")
        }
        guard let data = fm.contents(atPath: infoPath),
              var json = String(data: data, encoding: .utf8),
              json.contains("windows_x86_64_release/webgpu_dawn.lib") else {
            return
        }
        json = json.replacingOccurrences(
            of: "windows_x86_64_release/webgpu_dawn.lib",
            with: "windows_x86_64_release/libwebgpu_dawn.lib"
        )
        try json.write(toFile: infoPath, atomically: true, encoding: .utf8)
        Diagnostics.remark("FixWebGPUWindowsArtifact: updated info.json to reference libwebgpu_dawn.lib")
    }
}

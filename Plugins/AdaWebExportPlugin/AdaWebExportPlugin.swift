//
//  AdaWebExportPlugin.swift
//  AdaEngine
//

import Foundation
import PackagePlugin

@main
struct AdaWebExportPlugin: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        let options: ExportOptions
        do {
            options = try ExportOptions(arguments: arguments, packageDirectory: context.package.directoryURL)
        } catch ExportError.help {
            FileHandle.standardOutput.write(Data(ExportError.help.description.utf8))
            FileHandle.standardOutput.write(Data("\n".utf8))
            return
        }
        let sdk = try options.swiftSDK ?? detectWasmSDK()

        Diagnostics.remark("Building \(options.product) for WebAssembly with Swift SDK \(sdk)")
        try run(
            executable: "/usr/bin/env",
            arguments: [
                "swift",
                "build",
                "--product",
                options.product,
                "--swift-sdk",
                sdk,
                "-c",
                options.configuration.rawValue,
                "-Xswiftc",
                "-Xclang-linker",
                "-Xswiftc",
                "-mexec-model=reactor"
            ],
            workingDirectory: context.package.directoryURL
        )

        let wasm = try findBuiltWasm(
            product: options.product,
            configuration: options.configuration,
            packageDirectory: context.package.directoryURL
        )

        try exportBundle(
            wasm: wasm,
            options: options,
            packageDirectory: context.package.directoryURL
        )

        Diagnostics.remark("Exported AdaEngine web app to \(options.outputDirectory.path())")

        if options.serve {
            try serve(directory: options.outputDirectory)
        }
    }

    private func detectWasmSDK() throws -> String {
        let output = try capture(
            executable: "/usr/bin/env",
            arguments: ["swift", "sdk", "list"],
            workingDirectory: nil
        )

        if let sdk = output
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .flatMap({ line -> [String] in
                line.split(whereSeparator: \.isWhitespace).map(String.init)
            })
            .first(where: { $0.contains("_wasm") && !$0.contains("embedded") })
        {
            return sdk
        }

        throw ExportError.missingWasmSDK("""
        No Swift WebAssembly SDK was found.

        Install a Swift toolchain and matching WASM SDK, then retry. Swift.org documents the current flow here:
        https://www.swift.org/documentation/articles/wasm-getting-started.html

        You can also pass an explicit SDK id:
        swift package plugin --allow-writing-to-package-directory export-web --target <ProductName> --swift-sdk <sdk-id>
        """)
    }

    private func findBuiltWasm(
        product: String,
        configuration: ExportOptions.Configuration,
        packageDirectory: URL
    ) throws -> URL {
        let buildDirectory = packageDirectory.appending(components: ".build", directoryHint: .isDirectory)
        guard let enumerator = FileManager.default.enumerator(
            at: buildDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw ExportError.wasmNotFound(product)
        }

        let candidates = enumerator.compactMap { item -> URL? in
            guard let url = item as? URL else {
                return nil
            }
            guard url.lastPathComponent == "\(product).wasm" else {
                return nil
            }
            guard url.pathComponents.contains(configuration.rawValue) else {
                return nil
            }
            return url
        }

        guard let wasm = candidates.sorted(by: { $0.path.count < $1.path.count }).last else {
            throw ExportError.wasmNotFound(product)
        }

        return wasm
    }

    private func exportBundle(
        wasm: URL,
        options: ExportOptions,
        packageDirectory: URL
    ) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: options.outputDirectory, withIntermediateDirectories: true)

        let wasmOutput = options.outputDirectory.appending(component: "\(options.product).wasm", directoryHint: .notDirectory)
        try replaceItem(at: wasmOutput, with: wasm)

        let assetsSource = packageDirectory.appending(component: "Assets", directoryHint: .isDirectory)
        let assetsDestination = options.outputDirectory.appending(component: "Assets", directoryHint: .isDirectory)
        if fileManager.fileExists(atPath: assetsSource.path()) {
            if fileManager.fileExists(atPath: assetsDestination.path()) {
                try fileManager.removeItem(at: assetsDestination)
            }
            try fileManager.copyItem(at: assetsSource, to: assetsDestination)
        }

        try indexHTML(product: options.product).write(
            to: options.outputDirectory.appending(component: "index.html", directoryHint: .notDirectory),
            atomically: true,
            encoding: .utf8
        )
        try mainJS(product: options.product).write(
            to: options.outputDirectory.appending(component: "main.js", directoryHint: .notDirectory),
            atomically: true,
            encoding: .utf8
        )
        try packageJSON(product: options.product).write(
            to: options.outputDirectory.appending(component: "package.json", directoryHint: .notDirectory),
            atomically: true,
            encoding: .utf8
        )
        try manifestJSON(product: options.product).write(
            to: options.outputDirectory.appending(component: "ada-web-manifest.json", directoryHint: .notDirectory),
            atomically: true,
            encoding: .utf8
        )
    }

    private func replaceItem(at destination: URL, with source: URL) throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destination.path()) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: source, to: destination)
    }

    private func serve(directory: URL) throws {
        Diagnostics.remark("Serving \(directory.path()) at http://127.0.0.1:8080")
        try run(
            executable: "/usr/bin/env",
            arguments: ["python3", "-m", "http.server", "8080", "--directory", directory.path()],
            workingDirectory: directory
        )
    }

    private func run(executable: String, arguments: [String], workingDirectory: URL?) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = workingDirectory
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ExportError.commandFailed(arguments.joined(separator: " "), process.terminationStatus)
        }
    }

    private func capture(executable: String, arguments: [String], workingDirectory: URL?) throws -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = workingDirectory
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: data, as: UTF8.self)
        guard process.terminationStatus == 0 else {
            throw ExportError.commandFailed(arguments.joined(separator: " "), process.terminationStatus)
        }
        return output
    }
}

private struct ExportOptions {
    enum Configuration: String {
        case debug
        case release
    }

    let product: String
    let outputDirectory: URL
    let swiftSDK: String?
    let configuration: Configuration
    let serve: Bool

    init(arguments: [String], packageDirectory: URL) throws {
        var product: String?
        var outputDirectory = packageDirectory.appending(components: "dist", "web", directoryHint: .isDirectory)
        var swiftSDK: String?
        var configuration = Configuration.release
        var serve = false

        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--target", "--product":
                index += 1
                guard index < arguments.count else {
                    throw ExportError.missingValue(argument)
                }
                product = arguments[index]
            case "--output":
                index += 1
                guard index < arguments.count else {
                    throw ExportError.missingValue(argument)
                }
                outputDirectory = URL(fileURLWithPath: arguments[index], relativeTo: packageDirectory)
                    .standardizedFileURL
            case "--swift-sdk":
                index += 1
                guard index < arguments.count else {
                    throw ExportError.missingValue(argument)
                }
                swiftSDK = arguments[index]
            case "--debug":
                configuration = .debug
            case "--release":
                configuration = .release
            case "--serve":
                serve = true
            case "--help", "-h":
                throw ExportError.help
            default:
                throw ExportError.unknownArgument(argument)
            }

            index += 1
        }

        guard let product else {
            throw ExportError.missingTarget
        }

        self.product = product
        self.outputDirectory = outputDirectory
        self.swiftSDK = swiftSDK
        self.configuration = configuration
        self.serve = serve
    }
}

private enum ExportError: LocalizedError, CustomStringConvertible {
    case help
    case missingTarget
    case missingValue(String)
    case missingWasmSDK(String)
    case unknownArgument(String)
    case commandFailed(String, Int32)
    case wasmNotFound(String)

    var errorDescription: String? {
        description
    }

    var description: String {
        switch self {
        case .help:
            return """
            Usage:
              swift package plugin --allow-writing-to-package-directory export-web --target <ProductName> [--output dist/web] [--swift-sdk <sdk-id>] [--debug|--release] [--serve]
            """
        case .missingTarget:
            return "Missing required --target <ProductName> argument."
        case .missingValue(let argument):
            return "Missing value for \(argument)."
        case .missingWasmSDK(let message):
            return message
        case .unknownArgument(let argument):
            return "Unknown argument: \(argument)"
        case .commandFailed(let command, let status):
            return "Command failed with exit code \(status): \(command)"
        case .wasmNotFound(let product):
            return "Could not find built \(product).wasm under .build."
        }
    }
}

private func indexHTML(product: String) -> String {
    """
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>\(product)</title>
      <style>
        html, body, #ada-canvas-root {
          width: 100%;
          height: 100%;
          margin: 0;
          overflow: hidden;
          background: #101014;
        }
        canvas {
          width: 100%;
          height: 100%;
          outline: none;
        }
      </style>
    </head>
    <body>
      <div id="ada-canvas-root"></div>
      <script type="module" src="./main.js"></script>
    </body>
    </html>
    """
}

private func mainJS(product: String) -> String {
    """
    import { WASI, File, OpenFile, ConsoleStdout } from "@bjorn3/browser_wasi_shim";
    import { SwiftRuntime } from "javascript-kit-swift";

    const wasmURL = new URL("./\(product).wasm", import.meta.url);
    const wasmBytes = await (await fetch(wasmURL)).arrayBuffer();
    const swift = new SwiftRuntime();
    const wasi = new WASI(["\(product).wasm"], [], [
      new OpenFile(new File([])),
      ConsoleStdout.lineBuffered((line) => console.log(line)),
      ConsoleStdout.lineBuffered((line) => console.warn(line)),
    ], { debug: false });

    const { instance } = await WebAssembly.instantiate(wasmBytes, {
      wasi_snapshot_preview1: wasi.wasiImport,
      javascript_kit: swift.wasmImports,
    });

    swift.setInstance(instance);
    wasi.initialize(instance);
    swift.main();
    """
}

private func packageJSON(product: String) -> String {
    """
    {
      "name": "\(product.lowercased())-ada-web",
      "private": true,
      "type": "module",
      "scripts": {
        "serve": "vite --host 127.0.0.1"
      },
      "dependencies": {
        "@bjorn3/browser_wasi_shim": "^0.4.1",
        "javascript-kit-swift": "0.0.0",
        "vite": "^5.0.0"
      },
      "devDependencies": {}
    }
    """
}

private func manifestJSON(product: String) -> String {
    """
    {
      "product": "\(product)",
      "wasm": "\(product).wasm",
      "canvasRoot": "ada-canvas-root",
      "assets": "Assets"
    }
    """
}

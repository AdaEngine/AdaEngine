//
//  File.swift
//  
//
//  Created by v.prusakov on 8/11/21.
//

import CSDL2
import Vulkan
import CVulkan

let SDL_WINDOWPOS_UNDEFINED_MASK: Int32 = 0x1FFF0000;
let SDL_WINDOWPOS_UNDEFINED = SDL_WINDOWPOS_UNDEFINED_MASK;

enum WindowFlags: UInt32 {
    case SDL_WINDOW_FULLSCREEN = 0x00000001
    case SDL_WINDOW_SHOWN = 0x00000004
    case SDL_WINDOW_HIDDEN = 0x00000008
    case SDL_WINDOW_RESIZABLE = 0x00000020
    case SDL_WINDOW_MINIMIZED = 0x00000040
    case SDL_WINDOW_MAXIMIZED = 0x00000080
    case SDL_WINDOW_ALWAYS_ON_TOP = 0x00008000
    case SDL_WINDOW_VULKAN = 0x10000000
}

public typealias SDLWindow = OpaquePointer?

public func initializeSwiftSDL2() {
    if SDL_Init(SDL_INIT_VIDEO|SDL_INIT_EVENTS) < 0 {
        print(lastSDLError())
        return
    }
}

public func deinitializeSwiftSDL2() {
    SDL_Quit()
}

public class Window {

    public var sdlPointer: SDLWindow

    public init?() {
        self.sdlPointer = SDL_CreateWindow(
                "Vulkan Sample", 100, 100, 1024, 768,
                WindowFlags.SDL_WINDOW_SHOWN.rawValue |
                WindowFlags.SDL_WINDOW_ALWAYS_ON_TOP.rawValue |
                WindowFlags.SDL_WINDOW_VULKAN.rawValue
        );

        guard sdlPointer != nil else {
            print("Error while creating window: \(lastSDLError())")
            return nil
        }
    }

    public func runMessageLoop() {
        var quit = false

        let e: UnsafeMutablePointer<SDL_Event>? = UnsafeMutablePointer<SDL_Event>.allocate(capacity: 1)

        while (!quit) {
            SDL_PollEvent(e)

            guard let event = e?.pointee else {
                continue
            }
        
            if event.type == SDL_QUIT.rawValue {
                quit = true
                break
            }
        }
    }

    public func createVulkanSurface(vulkan: VulkanInstance) throws -> Surface {
        var surface = VkSurfaceKHR(bitPattern: 0)

        if SDL_Vulkan_CreateSurface(sdlPointer, vulkan.pointer, &surface) != SDL_TRUE {
            throw lastSDLError()
        }

        return Surface(vulkan: vulkan, surface: surface!)
    }

    public func getInstanceExtensions() throws -> [String] {
        var opResult = SDL_FALSE
        var countArr: [UInt32] = [0]
        var result: [String] = []

        opResult = SDL_Vulkan_GetInstanceExtensions(self.sdlPointer, &countArr, nil)
        if opResult != SDL_TRUE {
            throw lastSDLError()
        }

        let count = Int(countArr[0])
        if count > 0 {
            let namesPtr = UnsafeMutablePointer<UnsafePointer<Int8>?>.allocate(capacity: count)
            defer {
                namesPtr.deallocate()
            }

            opResult = SDL_Vulkan_GetInstanceExtensions(self.sdlPointer, &countArr, namesPtr)
            
            if opResult == SDL_TRUE {
                for i in 0..<count {
                    let namePtr = namesPtr[i]
                    let newName = String(cString: namePtr!)
                    result.append(newName)
                }
            }
        }

        return result
    }

    deinit {
        //Destroy window
        SDL_DestroyWindow(sdlPointer);
    }
}

public enum SDLError: Error {
    case generic(msg: String)
    case vulkan(msg: String)
}

func lastSDLError() -> SDLError {
    let error = SDL_GetError()
    return .generic(msg: String(cString: error!))
}

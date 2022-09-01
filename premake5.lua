include "premake/swift.lua"
include "premake/dependencies.lua"

workspace "AdaEngine"
    configurations { "Debug", "Release" }
    targetdir ".build"
    startproject "AdaEditor"
    swiftversion "5.0"

    filter "language:C++ or language:C"
        architecture "x86_64"
    filter ""

outputdir = "%{cfg.buildcfg}-%{cfg.system}-%{cfg.architecture}"

group "Editor"
project "AdaEditor"
    location "Sources/AdaEditor"
    kind "ConsoleApp"

    links {
        "AdaEngine"
    }

    files {
        "Sources/%{prj.name}/**.swift",
        -- Assets
        "Sources/%{prj.name}/**.metal",
        "Sources/%{prj.name}/**.glsl",
        "Sources/%{prj.name}/**.png",
    }

    removefiles {
        "Sources/%{prj.name}/Derived",
        "Sources/%{prj.name}/Project.swift",
        "Sources/%{prj.name}/*.xcodeproj"
    }

group ""

group "Core"
project "AdaEngine"
    location "Sources/AdaEngine"
    kind "StaticLib"

    links {
        "Math",
        "Collections",
        "box2d",
        "libpng"
    }

    files {
        "Sources/%{prj.name}/**.swift",
        -- Assets
        "Sources/%{prj.name}/**.metal",
        "Sources/%{prj.name}/**.glsl",
        "Sources/%{prj.name}/**.png",
    }

    removefiles {
        "Sources/%{prj.name}/Derived",
        "Sources/%{prj.name}/Project.swift",
        "Sources/%{prj.name}/*.xcodeproj"
    }

    filter "system:macos"
        defines {
            "MACOS"
        }

project "Math" 
    location "Sources/Math"
    kind "StaticLib"

    files {
        "Sources/%{prj.name}/**.swift", 
    }
    
    removefiles {
        "Sources/%{prj.name}/Derived",
        "Sources/%{prj.name}/Project.swift",
        "Sources/%{prj.name}/*.xcodeproj"
    }

group ""

group "Dependencies"
include "vendors/swift-collections"
include "vendors/box2d"
include "vendors/libpng"
group ""
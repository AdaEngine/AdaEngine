project "libpng"
    kind "StaticLib"
    language "C++"
    cppdialect "C++14"

    pchheader "Sources/%{prj.name}/libpng.h"

    files {
        "Sources/%{prj.name}/**.h",
        "Sources/%{prj.name}/**.c",
    }

    -- includedirs { "Sources/%{prj.name}/." }
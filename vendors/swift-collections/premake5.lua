project "OrderedCollections"
    kind "StaticLib"

    files {
        "Sources/%{prj.name}/**.swift"
    }

project "DequeModule"
    kind "StaticLib"

    files {
        "Sources/%{prj.name}/**.swift"
    }

project "Collections"
    kind "StaticLib"

    files {
        "Sources/%{prj.name}/**.swift"
    }

    links {
        "DequeModule",
        "OrderedCollections"
    }
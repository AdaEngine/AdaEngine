// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// TODO: return zlib https://github.com/godotengine/godot/issues/24287
// here: msdf-atlas-gen/freetype/include/freetype/config/ftoption.h

let package = Package(
    name: "msdf-atlas-gen",
    platforms: [
        .iOS(.v13),
        .macOS(.v11),
    ],
    products: [
        .library(
            name: "MSDFAtlasGen",
            targets: ["MSDFAtlasGen"]
        )
    ],
    targets: [
        .target(
            name: "MSDFGen",
            dependencies: [
                "freetype",
                "tinyxml"
            ],
            path: "msdfgen",
            publicHeadersPath: ".",
            cxxSettings: [
                .define("MSDFGEN_USE_CPP11"),
                .headerSearchPath("..")
            ]
        ),
        .target(
            name: "MSDFAtlasGen",
            dependencies: [
                "MSDFGen"
            ],
            path: "msdf-atlas-gen",
            publicHeadersPath: ".",
            cxxSettings: [
                .define("_CRT_SECURE_NO_WARNINGS"),
                .headerSearchPath("..")
            ]
        ),
        .target(
            name: "freetype",
            path: "freetype",
            sources: [
                "src/autofit/autofit.c",
                "src/base/ftbase.c",
                "src/base/ftbbox.c",
                "src/base/ftbdf.c",
                "src/base/ftbitmap.c",
                "src/base/ftcid.c",
                "src/base/ftdebug.c",
                "src/base/ftfstype.c",
                "src/base/ftgasp.c",
                "src/base/ftglyph.c",
                "src/base/ftgxval.c",
                "src/base/ftinit.c",
                "src/base/ftmm.c",
                "src/base/ftotval.c",
                "src/base/ftpatent.c",
                "src/base/ftpfr.c",
                "src/base/ftstroke.c",
                "src/base/ftsynth.c",
                "src/base/ftsystem.c",
                "src/base/fttype1.c",
                "src/base/ftwinfnt.c",
                "src/bdf/bdf.c",
                "src/bzip2/ftbzip2.c",
                "src/cache/ftcache.c",
                "src/cff/cff.c",
                "src/cid/type1cid.c",
                "src/gzip/ftgzip.c",
                "src/lzw/ftlzw.c",
                "src/pcf/pcf.c",
                "src/pfr/pfr.c",
                "src/psaux/psaux.c",
                "src/pshinter/pshinter.c",
                "src/psnames/psnames.c",
                "src/raster/raster.c",
                "src/sdf/sdf.c",
                "src/sfnt/sfnt.c",
                "src/smooth/smooth.c",
                "src/truetype/truetype.c",
                "src/type1/type1.c",
                "src/type42/type42.c",
                "src/winfonts/winfnt.c"
            ],
            publicHeadersPath: "include",
            cSettings: [
                .define("FT2_BUILD_LIBRARY"),
                .define("_CRT_SECURE_NO_WARNINGS"),
                .define("_CRT_NONSTDC_NO_WARNINGS")
            ]
        ),
        .target(
            name: "tinyxml",
            path: "tinyxml",
            publicHeadersPath: "."
        )
    ],
    cLanguageStandard: .c11,
    cxxLanguageStandard: .cxx17
)

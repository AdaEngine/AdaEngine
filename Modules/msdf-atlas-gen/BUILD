cc_library(
    name = "freetype",
    hdrs = glob([
		"freetype/include/freetype/*.h",
		"freetype/include/freetype/config/**/*.h",
		"freetype/include/freetype/internal/**/*.h",
        "freetype/src/**/*.h",
        ]) + ["freetype/include/ft2build.h"], 
    srcs = [
		"freetype/src/autofit/autofit.c",
		"freetype/src/base/ftbase.c",
		"freetype/src/base/ftbbox.c",
		"freetype/src/base/ftbdf.c",
		"freetype/src/base/ftbitmap.c",
		"freetype/src/base/ftcid.c",
		"freetype/src/base/ftdebug.c",
		"freetype/src/base/ftfstype.c",
		"freetype/src/base/ftgasp.c",
		"freetype/src/base/ftglyph.c",
		"freetype/src/base/ftgxval.c",
		"freetype/src/base/ftinit.c",
		"freetype/src/base/ftmm.c",
		"freetype/src/base/ftotval.c",
		"freetype/src/base/ftpatent.c",
		"freetype/src/base/ftpfr.c",
		"freetype/src/base/ftstroke.c",
		"freetype/src/base/ftsynth.c",
		"freetype/src/base/ftsystem.c",
		"freetype/src/base/fttype1.c",
		"freetype/src/base/ftwinfnt.c",
		"freetype/src/bdf/bdf.c",
		"freetype/src/bzip2/ftbzip2.c",
		"freetype/src/cache/ftcache.c",
		"freetype/src/cff/cff.c",
        "freetype/src/cff/cffcmap.c",
		"freetype/src/cid/type1cid.c",
		"freetype/src/gzip/ftgzip.c",
		"freetype/src/lzw/ftlzw.c",
		"freetype/src/pcf/pcf.c",
        "freetype/src/pcf/pcfdrivr.c",
		"freetype/src/pfr/pfr.c",
		"freetype/src/psaux/psaux.c",
		"freetype/src/pshinter/pshinter.c",
		"freetype/src/psnames/psnames.c",
		"freetype/src/raster/raster.c",
		"freetype/src/sdf/sdf.c",
		"freetype/src/sfnt/sfnt.c",
		"freetype/src/smooth/smooth.c",
		"freetype/src/truetype/truetype.c",
		"freetype/src/type1/type1.c",
		"freetype/src/type42/type42.c",
        "freetype/src/type42/t42drivr.c",
		"freetype/src/winfonts/winfnt.c"
    ],
    includes = ["freetype/include"],
    defines = [
        "FT2_BUILD_LIBRARY=1",
        "_CRT_SECURE_NO_WARNINGS=1",
        "_CRT_NONSTDC_NO_WARNINGS=1"
    ],
    textual_hdrs = glob([
        "freetype/src/**/*.c"
    ])
)

cc_library(
    name = "tinyxml",
    hdrs = ["tinyxml/tinyxml2.h"],
    srcs = ["tinyxml/tinyxml2.cpp"],
    includes = ["tinyxml"]
)

cc_library(
    name = "MSDFGen",
    deps = [
        ":freetype",
        ":tinyxml"
    ],
    hdrs = glob([
        "msdfgen/core/*.hpp",
        "msdfgen/core/*.h",
        "msdfgen/ext/*.h",
        "msdfgen/*.h"
    ], exclude = ["msdfgen/resource.h"]),
    srcs = glob([
        "msdfgen/**/*.cpp"
    ]),
    includes = ["msdfgen"],
    defines = [
        "MSDFGEN_USE_CPP11"
    ]
)

cc_library(
    name = "MSDFAtlasGen",
    copts = [
        "-Wunused-function"
    ],
    defines = [
        "_CRT_SECURE_NO_WARNINGS=1",
    ],
    deps = [":MSDFGen"],
    hdrs = glob([
        "msdf-atlas-gen/*.h",
        "msdf-atlas-gen/*.hpp"
    ]),
    includes = ["msdf-atlas-gen"],
    srcs = glob([
        "msdf-atlas-gen/*.cpp"
    ]),
    visibility = ["//visibility:public"],
)
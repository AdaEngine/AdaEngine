cc_library(
    name = "libpng",
    srcs = [
        "Sources/libpng/png.c",
        "Sources/libpng/include/pngdebug.h",
        "Sources/libpng/pngerror.c",
        "Sources/libpng/pngget.c",
        "Sources/libpng/include/pnginfo.h",
        "Sources/libpng/include/pnglibconf.h",
        "Sources/libpng/pngmem.c",
        "Sources/libpng/pngpread.c",
        "Sources/libpng/include/pngpriv.h",
        "Sources/libpng/pngread.c",
        "Sources/libpng/pngrio.c",
        "Sources/libpng/pngrtran.c",
        "Sources/libpng/pngrutil.c",
        "Sources/libpng/pngset.c",
        "Sources/libpng/include/pngstruct.h",
        "Sources/libpng/pngtrans.c",
        "Sources/libpng/pngwio.c",
        "Sources/libpng/pngwrite.c",
        "Sources/libpng/pngwtran.c",
        "Sources/libpng/pngwutil.c",
    ] + select({
        "@platforms//cpu:arm64": [
            "Sources/libpng/arm/arm_init.c",
            "Sources/libpng/arm/filter_neon_intrinsics.c",
            "Sources/libpng/arm/palette_neon_intrinsics.c",
        ],
        "//conditions:default": [],
    }),
    hdrs = [
        "Sources/libpng/include/libpng.h",
        "Sources/libpng/include/png.h",
        "Sources/libpng/include/pngconf.h"
    ],
    includes = ["Sources/libpng/include"],
    defines = select({
        "@platforms//cpu:arm64": [
            "PNG_ARM_NEON_OPT=2",
        ],
        "//conditions:default": [],
    }),
    linkopts = ["-lm"],
    deps = ["@zlib"],
    visibility = ["//visibility:public"],
    tags = ["swift_module=libpng"]
)
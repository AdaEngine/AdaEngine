load("@build_bazel_rules_swift//swift:swift_interop_hint.bzl", "swift_interop_hint")

cc_library(
    name = "libpng",
    srcs = [
        "Sources/libpng/png.c",
        "Sources/libpng/pngerror.c",
        "Sources/libpng/pngget.c",
        "Sources/libpng/pngmem.c",
        "Sources/libpng/pngpread.c",
        "Sources/libpng/pngread.c",
        "Sources/libpng/pngrio.c",
        "Sources/libpng/pngrtran.c",
        "Sources/libpng/pngrutil.c",
        "Sources/libpng/pngset.c",
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
    hdrs = glob([
        "Sources/libpng/include/*.h"
    ]),
    defines = select({
        "@platforms//cpu:arm64": [
            "PNG_ARM_NEON_OPT=2",
        ],
        "//conditions:default": [],
    }),
    includes = [
        "Sources/libpng/include"
    ],
    linkopts = ["-lm"],
    deps = ["@zlib"],
    aspect_hints = ["libpng_cc"],
    visibility = ["//visibility:public"],
)

swift_interop_hint(
    name = "libpng_cc",
    module_name = "libpng",
    visibility = ["//visibility:public"]
)
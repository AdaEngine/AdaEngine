
cc_library(
    name = "SPIRV-Cross",
    srcs = [
        "spirv_cfg.cpp",
        "spirv_cpp.cpp",
        "spirv_cross.cpp",
        "spirv_cross_c.cpp",
        "spirv_cross_parsed_ir.cpp",
        "spirv_cross_util.cpp",
        "spirv_glsl.cpp",
        "spirv_hlsl.cpp",
        "spirv_msl.cpp",
        "spirv_parser.cpp",
        "spirv_reflect.cpp"
    ],
    hdrs = glob([
        "*.hpp",
        "*.h"
    ]),
    defines = [
        "SPIRV_CROSS_C_API_CPP=1",
        "SPIRV_CROSS_C_API_GLSL=1",
        "SPIRV_CROSS_C_API_HLSL=1",
        "SPIRV_CROSS_C_API_MSL=1",
        "SPIRV_CROSS_C_API_REFLECT=1",
    ],
    visibility = ["//visibility:public"],
    tags = ["swift_module=SPIRV_Cross"]
)
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_c_module")

cc_library(
    name = "miniaudio",
    hdrs = ["include/miniaudio.h"],
    srcs = ["miniaudio.c"],
    includes = ["include"],
    defines = [
        "MINIAUDIO_IMPLEMENTATION"
    ],
    visibility = ["//visibility:public"]
)
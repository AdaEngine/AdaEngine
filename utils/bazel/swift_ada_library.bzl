"""Convenience wrapper for swift_library targets using this repo's conventions"""

load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

def swift_ada_library(
    name, 
    deps = [], 
    data = [], 
    defines = [], 
    copts = [], 
    linkopts = [], 
    plugins = [], 
    linkstatic = True, 
    testonly = False, 
    visibility = ["//visibility:public"]
):
    swift_library(
        name = name,
        srcs = native.glob(
            ["**/*.swift"],
            exclude = ["**/*.docc/**"],
            allow_empty = False,
        ),
        deps = deps,
        module_name = name,
        data = data,
        defines = defines,
        copts = copts,
        plugins = plugins,
        linkopts = linkopts,
        linkstatic = linkstatic,
        testonly = testonly,
        visibility = visibility
    )
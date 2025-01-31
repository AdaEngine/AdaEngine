"""Convenience wrapper for swift_library targets using this repo's conventions"""

# load("@build_bazel_rules_swift//swift:swift.bzl", "swift_c_module")

def cc_ada_library(name, srcs = [], includes = ["include"], copts = [], linkopts = [], deps = [], defines = [], data = [], testonly = False):

    # cxx_lib_name = "_{}_cxx_lib".format(name)

    native.cc_library(
        name = name,
        srcs = native.glob(
            [
                "Sources/{}/**/*.c".format(name), 
                "Sources/{}/**/*.cpp".format(name), 
                "Sources/{}/**/*.cc".format(name)
            ],
            exclude = ["**/*.docc/**"],
            allow_empty = True,
        ) + srcs,
        hdrs = native.glob(
            [
                "Sources/{}/**/*.h".format(name),
                "Sources/{}/**/*.hpp".format(name)
            ],
            exclude = ["**/*.docc/**"],
            allow_empty = True,
        ),
        includes = includes,
        deps = deps,
        data = data,
        linkopts = linkopts,
        copts = copts,
        defines = defines,
        testonly = testonly,
        aspect_hints = ["@build_bazel_rules_swift//swift:auto_module"],
        visibility = ["//:__subpackages__"]
    )

    # swift_c_module(
    #     name = name,
    #     module_map = "Sources/{}/module.modulemap".format(name),
    #     module_name = name,
    #     deps = [cxx_lib_name]
    # )
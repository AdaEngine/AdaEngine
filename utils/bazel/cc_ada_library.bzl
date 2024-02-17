"""Convenience wrapper for swift_library targets using this repo's conventions"""

load("@build_bazel_rules_swift//swift:swift.bzl", "swift_c_module")

def cc_ada_library(name, srcs = [], includes = ["include"], deps = [], defines = [], data = [], testonly = False):

    cxx_lib_name = "_{}_cxx_lib".format(name)

    native.cc_library(
        name = cxx_lib_name,
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
        defines = defines,
        testonly = testonly,
        visibility = ["//:__subpackages__"]
    )

    swift_c_module(
        name = name,
        module_map = "Sources/{}/module.modulemap".format(name),
        module_name = name,
        deps = [cxx_lib_name]
    )
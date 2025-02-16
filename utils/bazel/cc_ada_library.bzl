"""Convenience wrapper for swift_library targets using this repo's conventions"""

load("@build_bazel_rules_swift//swift:swift_interop_hint.bzl", "swift_interop_hint")

def cc_ada_library(name, srcs = [], includes = ["include"], copts = [], linkopts = [], deps = [], defines = [], data = [], testonly = False):
    cxx_lib_name = "_{}_cxx_lib".format(name)

    native.cc_library(
        name = name,
        srcs = native.glob(
            [
                "**/*.c".format(name), 
                "**/*.cpp".format(name), 
                "**/*.cc".format(name)
            ],
            exclude = ["**/*.docc/**"],
            allow_empty = True,
        ) + srcs,
        hdrs = native.glob(
            [
                "**/*.h".format(name),
                "**/*.hpp".format(name)
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
        aspect_hints = [cxx_lib_name],
        visibility = ["//:__subpackages__"]
    )

    swift_interop_hint(
        name = cxx_lib_name,
        module_name = name,
    )
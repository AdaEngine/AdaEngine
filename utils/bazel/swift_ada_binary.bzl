"""Convenience wrapper for swift_library targets using this repo's conventions"""

load("@build_bazel_rules_swift//swift:swift_binary.bzl", "swift_binary")

def swift_ada_binary(name, deps = [], data = [], defines = [], copts = [], testonly = False):
    swift_binary(
        name = name,
        srcs = native.glob(
            ["Sources/{}/**/*.swift".format(name)],
            exclude = ["**/*.docc/**"],
            allow_empty = False,
        ),
        deps = deps,
        data = data,
        defines = defines,
        copts = copts,
        testonly = testonly
    )

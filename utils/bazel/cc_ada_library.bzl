"""Convenience wrapper for swift_library targets using this repo's conventions"""

def cc_ada_library(name, includes = ["include"], deps = [], defines = [], data = [], testonly = False):
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
        ),
        hdrs = native.glob(
            ["Sources/{}/**/*.h".format(name)],
            exclude = ["**/*.docc/**"],
            allow_empty = True,
        ),
        includes = includes,
        deps = deps,
        data = data,
        defines = defines,
        testonly = testonly
    )
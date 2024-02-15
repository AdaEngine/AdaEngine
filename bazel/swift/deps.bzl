load("@rules_swift_package_manager//swiftpkg:defs.bzl", "swift_package")

def swift_dependencies():
    # branch: main
    swift_package(
        name = "swiftpkg_box2d_swift",
        commit = "bb0f705f88737248f34835f707c8f8027efed7d4",
        dependencies_index = "@//bazel/swift:deps_index.json",
        remote = "https://github.com/AdaEngine/box2d-swift",
    )

    # branch: main
    swift_package(
        name = "swiftpkg_glslang",
        commit = "40069c0b63762e408051851ffe7aa92765c23284",
        dependencies_index = "@//bazel/swift:deps_index.json",
        remote = "https://github.com/AdaEngine/glslang",
    )

    # branch: master
    swift_package(
        name = "swiftpkg_msdf_atlas_gen",
        commit = "be243203aeb31a1799866c73de79ed6400a0bd51",
        dependencies_index = "@//bazel/swift:deps_index.json",
        remote = "https://github.com/AdaEngine/msdf-atlas-gen",
    )

    # branch: main
    swift_package(
        name = "swiftpkg_spirv_cross",
        commit = "9011c07c49b75b97500fb61bbbf33284f38c4ee8",
        dependencies_index = "@//bazel/swift:deps_index.json",
        remote = "https://github.com/AdaEngine/SPIRV-Cross",
    )

    # branch: main
    swift_package(
        name = "swiftpkg_swift_collections",
        commit = "ca8b4ab855f4b8075c1fd29eb50db756b1688e61",
        dependencies_index = "@//bazel/swift:deps_index.json",
        remote = "https://github.com/apple/swift-collections",
    )

    # version: 5.0.6
    swift_package(
        name = "swiftpkg_yams",
        commit = "0d9ee7ea8c4ebd4a489ad7a73d5c6cad55d6fed3",
        dependencies_index = "@//bazel/swift:deps_index.json",
        remote = "https://github.com/jpsim/Yams",
    )

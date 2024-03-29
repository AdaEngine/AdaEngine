load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")

def _ada_engine_vendor(_):
    git_repository(
        name = "MSDFAtlasGen",
        commit = "5db5b7f5136ce124ccc2c1b84a424b835f0b9f64",
        remote = "https://github.com/AdaEngine/msdf-atlas-gen"
    )

    git_repository(
        name = "glslang",
        commit = "28dab900903b7341ef7dbab89df1e44958b8a8b0",
        remote = "https://github.com/AdaEngine/glslang"
    )

    git_repository(
        name = "SPIRV-Cross",
        commit = "e67c6acc5b577a36f9166d70bfd5c5dc6f8cdbe9",
        remote = "https://github.com/AdaEngine/SPIRV-Cross"
    )

    git_repository(
        name = "libpng",
        commit = "22465834d2d062f9d8ab5b7fcb5955df6d678c2b",
        remote = "https://github.com/AdaEngine/libpng"
    )

    git_repository(
        name = "miniaudio",
        commit = "490c6955d4fa1d9307123abc379818f561d80394",
        remote = "https://github.com/AdaEngine/miniaudio"
    )

ada_engine_vendor = module_extension(implementation = _ada_engine_vendor)
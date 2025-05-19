load("//utils/bazel:cc_ada_library.bzl", "cc_ada_library")

package(default_visibility = ["//visibility:public"])

VULKAN_LINK_OPTS = select({
    "@platforms//os:macos": [
        "-rpath",
        "/usr/local/lib",
    ],
    "@platforms//os:ios": [
        "-rpath",
        "/usr/local/lib",
    ],
    "@platforms//os:tvos": [
        "-rpath",
        "/usr/local/lib",
    ],
    "@platforms//os:windows": [],
    "@platforms//os:linux": [
        "-rpath",
        "/usr/local/lib",
    ],
    "@platforms//os:android": [
        "-rpath",
        "/usr/local/lib",
    ],
    "//conditions:default": [],
})

cc_ada_library(
    name = "CVulkan",
    defines = select({
        "@platforms//os:macos": [
            "VK_USE_PLATFORM_MACOS_MVK",
            "VK_USE_PLATFORM_METAL_EXT",
        ],
        "@platforms//os:ios": [
            "VK_USE_PLATFORM_IOS_MVK",
            "VK_USE_PLATFORM_METAL_EXT",
        ],
        "@platforms//os:tvos": [
            "VK_USE_PLATFORM_IOS_MVK",
            "VK_USE_PLATFORM_METAL_EXT",
        ],
        "@platforms//os:windows": [
            "VK_USE_PLATFORM_WIN32_KHR",
        ],
        "@platforms//os:linux": [
            "VK_USE_PLATFORM_XLIB_KHR",
        ],
        "@platforms//os:android": [
            "VK_USE_PLATFORM_ANDROID_KHR",
        ],
        "//conditions:default": [],
    }),
    linkopts = VULKAN_LINK_OPTS,
    deps = [
        "@rules_vulkan//vulkan:vulkan_cc_library",
    ],
)

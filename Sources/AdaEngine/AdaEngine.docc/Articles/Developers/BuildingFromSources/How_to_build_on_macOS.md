# How to build on macOS


### Requirements
First of all you need to download next tools:

- Swift (shipped by Xcode)
- [VulkanSDK](https://sdk.lunarg.com/sdk/download/latest/mac/vulkan-sdk.dmg)
- [Bazel](https://bazel.build/install/os-x)

#### IDEs

Because AdaEngine use Bazel as main build tools, you can use any popular IDE that support Bazel plugin

- Xcode
- Intelij IDEA
- Visual Studio Code

### First preparation

Setup actual bazel version, using [next tutorial](https://bazel.build/install/os-x) or using next command:

```sh
brew install bazel
```

After installing bazel, download [VulkanSDK](https://sdk.lunarg.com/sdk/download/latest/mac/vulkan-sdk.dmg) and install path to vulkan libary. 

```sh
export VULKAN_SDK="/Users/{YOUR_NAME}/VulkanSDK/{VULKAN_VERSION}/macOS"
```

where:
- `VULKAN_VERSION` - latest version of vulkan
- `YOUR_NAME` - your local user name

### Xcode

By default, Xcode doesn't look into you bash/zsh profiles and you need to install path to Vulkan manually. 
In Xcode setup environment variable `VULKAN_SDK` into `Xcode -> Settings -> Locations -> Custom Paths`. This path is simillar that we describe before.

After all, we should create our project file for Xcode, using make command:

```sh
make xcodeproj
```

If command finished succefully, you can open `AdaEngine.xcodeproj` file from Finder or using terminal command:

```sh
xed AdaEngine.xcodeproj
```


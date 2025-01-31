install_vulkan:
	cp Sources/CVulkan/vulkan.pc /usr/local/lib/pkgconfig/vulkan.pc
	pkg-config --libs --cflags vulkan

compile_shaders:
		${VULKAN_SDK}/bin/glslc -fshader-stage=vert Sources/AdaEditor/Assets/circle.glsl -o Sources/AdaEditor/Assets/circle.glsl.spv

setup_project:
	bazel run gazelle_bin
	bazel run swift_update_pkgs
		
xcodeproj:
	bazel run utils/bazel:xcodeproj
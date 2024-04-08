install_vulkan:
	cp Modules/Vulkan/Sources/CVulkan/vulkan.pc /usr/local/lib/pkgconfig/vulkan.pc
	pkg-config --libs --cflags vulkan

xcodeproj:
	bazel run utils/bazel:xcodeproj

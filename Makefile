install_vulkan:
	cp Sources/CVulkan/vulkan.pc /usr/local/lib/pkgconfig/vulkan.pc
	pkg-config --libs --cflags vulkan

compile_shaders:
		${VULKAN_SDK}/bin/glslc Sources/AdaEngine/Rendering/Shaders/shader.frag -o Sources/AdaEngine/Rendering/Shaders/shader.frag.spv
		${VULKAN_SDK}/bin/glslc Sources/AdaEngine/Rendering/Shaders/shader.vert -o Sources/AdaEngine/Rendering/Shaders/shader.vert.spv

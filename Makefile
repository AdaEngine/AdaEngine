install_vulkan:
	cp Sources/CVulkan/vulkan.pc /usr/local/lib/pkgconfig/vulkan.pc
	pkg-config --libs --cflags vulkan

compile_shaders:
		${VULKAN_SDK}/bin/glslc Sources/AdaEngine/Rendering/Shaders/GLSL/shader.frag -o Sources/AdaEngine/Rendering/Shaders/GLSL/shader.frag.spv
		${VULKAN_SDK}/bin/glslc Sources/AdaEngine/Rendering/Shaders/GLSL/shader.vert -o Sources/AdaEngine/Rendering/Shaders/GLSL/shader.vert.spv
		
xcodeproj:
	tuist fetch
	tuist generate

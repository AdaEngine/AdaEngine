#include <vulkan/vulkan.h>

static uint32_t vkMakeApiVersion(uint32_t v1, uint32_t v2, uint32_t v3) {
    return VK_MAKE_VERSION(v1, v2, v3);
}

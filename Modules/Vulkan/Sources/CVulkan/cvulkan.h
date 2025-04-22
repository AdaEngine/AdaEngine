#include <vulkan/vulkan.h>

static uint32_t vkApiVersion_1_2() {
    return VK_API_VERSION_1_2;
}

static uint32_t vkApiVersion_1_0() {
    return VK_API_VERSION_1_0;
}

static uint32_t vkMakeApiVersion(uint32_t v1, uint32_t v2, uint32_t v3) {
    return VK_MAKE_VERSION(v1, v2, v3);
}

static uint32_t vkVersionMajor(uint32_t version) {
    return VK_VERSION_MAJOR(version);
}

static uint32_t vkVersionMinor(uint32_t version) {
    return VK_VERSION_MINOR(version);
}

static uint32_t vkVersionPatch(uint32_t version) {
    return VK_VERSION_PATCH(version);
}

typedef struct VkMetalSurfaceCreateInfoEXT_Swift {
    VkStructureType         sType;
    const void*             pNext;
    VkFlags                 flags;
    const void*             pLayer;
} VkMetalSurfaceCreateInfoEXT_Swift;

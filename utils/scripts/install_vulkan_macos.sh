#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_message() {
    echo -e "${2}${1}${NC}"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    print_message "This script is intended for macOS only." "$RED"
    exit 1
fi

# Check if Vulkan SDK is installed
if [ -d "/usr/local/share/vulkan" ] || [ -d "$HOME/vulkansdk" ]; then
    print_message "Vulkan SDK is already installed." "$GREEN"
    exit 0
fi

print_message "Vulkan SDK not found. Starting installation..." "$YELLOW"

# Create temporary directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR" || exit 1

# Get the latest Vulkan SDK version
print_message "Fetching latest Vulkan SDK version..." "$YELLOW"
LATEST_VERSION=$(curl -s https://vulkan.lunarg.com/sdk/latest/mac.json | grep -o '"version": "[^"]*' | cut -d'"' -f4)

if [ -z "$LATEST_VERSION" ]; then
    print_message "Failed to fetch latest version. Please check your internet connection." "$RED"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Download the SDK
DOWNLOAD_URL="https://sdk.lunarg.com/sdk/download/${LATEST_VERSION}/mac/vulkansdk-macos-${LATEST_VERSION}.dmg"
print_message "Downloading Vulkan SDK ${LATEST_VERSION}..." "$YELLOW"

if ! curl -L -o vulkansdk.dmg "$DOWNLOAD_URL"; then
    print_message "Failed to download Vulkan SDK." "$RED"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Mount the DMG
print_message "Installing Vulkan SDK..." "$YELLOW"
hdiutil attach vulkansdk.dmg

# Find the mounted volume
VOLUME_PATH=$(hdiutil info | grep "VulkanSDK" | awk '{print $3}')

if [ -z "$VOLUME_PATH" ]; then
    print_message "Failed to mount Vulkan SDK installer." "$RED"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Install the SDK
if ! cp -R "$VOLUME_PATH/VulkanSDK" "$HOME/"; then
    print_message "Failed to install Vulkan SDK." "$RED"
    hdiutil detach "$VOLUME_PATH"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Unmount the DMG
hdiutil detach "$VOLUME_PATH"

# Clean up
rm -rf "$TEMP_DIR"

# Set up environment variables
print_message "Setting up environment variables..." "$YELLOW"
echo 'export VULKAN_SDK=$HOME/vulkansdk/macOS' >> ~/.zshrc
echo 'export PATH=$VULKAN_SDK/bin:$PATH' >> ~/.zshrc
echo 'export DYLD_LIBRARY_PATH=$VULKAN_SDK/lib:$DYLD_LIBRARY_PATH' >> ~/.zshrc
echo 'export VK_ICD_FILENAMES=$VULKAN_SDK/share/vulkan/icd.d/MoltenVK_icd.json' >> ~/.zshrc

print_message "Vulkan SDK ${LATEST_VERSION} has been successfully installed!" "$GREEN"
print_message "Please restart your terminal or run 'source ~/.zshrc' to apply the changes." "$YELLOW"

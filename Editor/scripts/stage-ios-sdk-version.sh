#!/bin/zsh
set -euo pipefail

# Xcode's SwiftPM executable link can record the deployment target as its SDK.
# The app wrapper copies that executable, so repair its SDK provenance before CodeSign.
# All sources were compiled against SDKROOT; keep the app's minimum OS unchanged.
binary="${1:?Pass the staged app executable}"
case "${PLATFORM_NAME:-}" in
  iphoneos) platform=ios ;;
  iphonesimulator) platform=iossim ;;
  *) exit 0 ;;
esac

staged_binary="${binary}.sdk-version"
trap 'rm -f "${staged_binary}"' EXIT
xcrun vtool -set-build-version "${platform}" \
  "${IPHONEOS_DEPLOYMENT_TARGET:?Missing deployment target}" "${SDK_VERSION:?Missing SDK version}" \
  -replace -output "${staged_binary}" "${binary}"
/bin/chmod +x "${staged_binary}"
/bin/mv -f "${staged_binary}" "${binary}"

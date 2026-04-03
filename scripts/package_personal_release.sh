#!/usr/bin/env bash
# Release 빌드 후 개인용 배포물(ZIP) 생성
# 사용: ./scripts/package_personal_release.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJECT="${PROJECT_ROOT}/WindowSnap.xcodeproj"
SCHEME="WindowSnap"
CONFIGURATION="Release"
BUILD_DIR="${PROJECT_ROOT}/build/${CONFIGURATION}"
DIST_DIR="${PROJECT_ROOT}/dist"
APP_NAME="WindowSnap.app"
ZIP_NAME="WindowSnap-${CONFIGURATION}-$(date +%Y%m%d).zip"

echo "==> Building ${SCHEME} (${CONFIGURATION})..."
xcodebuild \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -destination "platform=macOS,arch=arm64" \
  -derivedDataPath "${PROJECT_ROOT}/build/DerivedData-${CONFIGURATION}" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=YES \
  build

BUILT_APP="${PROJECT_ROOT}/build/DerivedData-${CONFIGURATION}/Build/Products/${CONFIGURATION}/${APP_NAME}"
if [[ ! -d "${BUILT_APP}" ]]; then
  echo "error: Built app not found at ${BUILT_APP}" >&2
  exit 1
fi

mkdir -p "${DIST_DIR}"
rm -f "${DIST_DIR}/${ZIP_NAME}"

echo "==> Creating ${DIST_DIR}/${ZIP_NAME}..."
ditto -c -k --sequesterRsrc --keepParent "${BUILT_APP}" "${DIST_DIR}/${ZIP_NAME}"

echo "==> Done."
echo "    Output: ${DIST_DIR}/${ZIP_NAME}"
echo ""
echo "    Install: unzip, then drag WindowSnap.app to Applications."
echo "    If macOS blocks the app: System Settings > Privacy & Security > Open Anyway"
echo "    Or after first open attempt: xattr -dr com.apple.quarantine /path/to/WindowSnap.app"

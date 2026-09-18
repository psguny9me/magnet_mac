#!/usr/bin/env bash
# 매 실행마다 clean 후 Release 빌드하고, 그 결과로 개인용 배포물(ZIP) 생성
# 사용: ./scripts/package_personal_release.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJECT="${PROJECT_ROOT}/WindowSnap.xcodeproj"
SCHEME="WindowSnap"
CONFIGURATION="Release"
DERIVED_DATA="${PROJECT_ROOT}/build/DerivedData-${CONFIGURATION}"
DIST_DIR="${PROJECT_ROOT}/dist"
APP_NAME="WindowSnap.app"
ZIP_NAME="WindowSnap-${CONFIGURATION}-$(date +%Y%m%d).zip"

# 서명 ID 선택.
# ad-hoc("-") 서명은 빌드마다 cdhash가 바뀌어 손쉬운 사용(Accessibility) 권한이 재설치 때마다 초기화된다.
# 키체인에 Apple Development 인증서가 있으면 그것으로 서명해 권한이 유지되게 한다.
# 환경변수 WINDOWSNAP_SIGN_IDENTITY로 강제 지정할 수 있다.
if [[ -n "${WINDOWSNAP_SIGN_IDENTITY:-}" ]]; then
  SIGN_IDENTITY="${WINDOWSNAP_SIGN_IDENTITY}"
else
  SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/.*"\(Apple Development: [^"]*\)".*/\1/p' | head -n 1)"
  SIGN_IDENTITY="${SIGN_IDENTITY:--}"
fi
if [[ "${SIGN_IDENTITY}" == "-" ]]; then
  echo "warning: Apple Development 인증서가 없어 ad-hoc 서명합니다. 재설치 시 접근성 권한을 다시 허용해야 합니다." >&2
fi
# Automatic 서명 스타일은 팀 선택을 요구하므로 명령줄 빌드에서는 Manual로 고정한다.
# 팀 ID는 인증서 subject의 OU 필드에 있다 (이름 뒤 괄호의 값은 팀 ID가 아니라 인증서 사용자 ID)
DEVELOPMENT_TEAM_ID=""
if [[ "${SIGN_IDENTITY}" != "-" ]]; then
  DEVELOPMENT_TEAM_ID="$(security find-certificate -c "${SIGN_IDENTITY}" -p 2>/dev/null \
    | openssl x509 -noout -subject 2>/dev/null | sed -n 's/.*OU *= *\([A-Z0-9]*\).*/\1/p')"
fi
echo "==> Code sign identity: ${SIGN_IDENTITY} (team: ${DEVELOPMENT_TEAM_ID:-none})"

echo "==> Removing previous ${CONFIGURATION} DerivedData (clean slate)..."
rm -rf "${DERIVED_DATA}"

echo "==> Building ${SCHEME} (${CONFIGURATION})..."
xcodebuild \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -destination "platform=macOS,arch=arm64" \
  -derivedDataPath "${DERIVED_DATA}" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="${SIGN_IDENTITY}" \
  DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM_ID}" \
  CODE_SIGNING_ALLOWED=YES \
  build

BUILT_APP="${DERIVED_DATA}/Build/Products/${CONFIGURATION}/${APP_NAME}"
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

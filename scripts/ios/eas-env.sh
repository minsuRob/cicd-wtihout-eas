#!/bin/bash

# EAS 환경 래퍼 스크립트
# Python의 가상환경처럼 특정 환경에서 EAS 명령을 실행합니다.
#
# 사용법:
#   ./scripts/ios/eas-env.sh [환경이름] <eas 명령>
#
# 예시:
#   ./scripts/ios/eas-env.sh production login
#   ./scripts/ios/eas-env.sh staging whoami
#   ./scripts/ios/eas-env.sh production build --platform ios

set -euo pipefail

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 인자 확인
if [ $# -lt 1 ]; then
    echo -e "${RED}사용법: $0 [환경이름] <eas 명령>${NC}"
    echo ""
    echo "예시:"
    echo "  $0 production login"
    echo "  $0 staging whoami"
    echo "  $0 production build --platform ios"
    exit 1
fi

ENV_NAME="$1"
shift  # 환경 이름 제거, 나머지가 EAS 명령

# 프로젝트 루트 경로
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# 독립 환경 디렉토리
EAS_ENV_DIR="$PROJECT_ROOT/.eas-env/$ENV_NAME"

# 독립 환경 디렉토리 생성
mkdir -p "$EAS_ENV_DIR/.expo"
mkdir -p "$EAS_ENV_DIR/.eas"

# 원본 HOME 저장
ORIGINAL_HOME="$HOME"

# 독립 환경의 HOME으로 임시 변경
export HOME="$EAS_ENV_DIR"

echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${GREEN}  EAS 독립 세션 환경에서 명령 실행${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo "환경 이름: $ENV_NAME"
echo "독립 환경 디렉토리: $EAS_ENV_DIR"
echo "실행 명령: eas $*"
echo ""

# EAS 명령 실행
if command -v eas &> /dev/null; then
    eas "$@"
    EXIT_CODE=$?
else
    echo -e "${RED}❌ EAS CLI를 찾을 수 없습니다.${NC}"
    echo "다음 명령으로 설치하세요: npm install -g eas-cli"
    EXIT_CODE=1
fi

# 원본 HOME으로 복원
export HOME="$ORIGINAL_HOME"

exit $EXIT_CODE

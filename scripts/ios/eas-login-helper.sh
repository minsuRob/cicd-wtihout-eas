#!/bin/bash

# EAS 독립 세션 로그인 헬퍼 스크립트
# Python의 가상환경처럼 별도의 환경에서 EAS CLI를 사용할 수 있게 해주는 스크립트입니다.
#
# 사용법:
#   source scripts/ios/eas-login-helper.sh [환경이름]
#
# 예시:
#   source scripts/ios/eas-login-helper.sh production
#   eas login
#   eas build:configure
#   exit  # 또는 deactivate_eas_env로 환경 종료
#
# 기존 환경에 영향을 주지 않고 독립적으로 EAS를 사용할 수 있습니다.

set -euo pipefail

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 환경 이름 (기본값: "isolated")
ENV_NAME="${1:-isolated}"

# 프로젝트 루트 경로
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# 독립 환경 디렉토리 (프로젝트 내부에 생성)
EAS_ENV_DIR="$PROJECT_ROOT/.eas-env/$ENV_NAME"

# 원본 HOME 환경 변수 백업
if [ -z "${_ORIGINAL_HOME:-}" ]; then
    export _ORIGINAL_HOME="$HOME"
fi

# 원본 PATH 백업 (나중에 복원하기 위해)
if [ -z "${_ORIGINAL_PATH:-}" ]; then
    export _ORIGINAL_PATH="$PATH"
fi

# 독립 환경 디렉토리 생성
mkdir -p "$EAS_ENV_DIR/.expo"
mkdir -p "$EAS_ENV_DIR/.eas"

# 독립 환경의 HOME으로 설정
export HOME="$EAS_ENV_DIR"

echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${GREEN}  EAS 독립 세션 환경 활성화${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""
echo "환경 이름: $ENV_NAME"
echo "독립 환경 디렉토리: $EAS_ENV_DIR"
echo "원본 HOME: $_ORIGINAL_HOME"
echo ""
echo -e "${YELLOW}이제 이 쉘에서 EAS CLI 명령을 실행할 수 있습니다:${NC}"
echo "  eas login"
echo "  eas whoami"
echo "  eas build:configure"
echo ""
echo -e "${YELLOW}환경을 종료하려면 다음 중 하나를 실행하세요:${NC}"
echo "  deactivate_eas_env"
echo "  exit"
echo ""
echo -e "${GREEN}✅ 독립 환경이 활성화되었습니다.${NC}"
echo ""

# 환경 종료 함수
deactivate_eas_env() {
    if [ -n "${_ORIGINAL_HOME:-}" ]; then
        export HOME="$_ORIGINAL_HOME"
        unset _ORIGINAL_HOME
    fi
    
    if [ -n "${_ORIGINAL_PATH:-}" ]; then
        export PATH="$_ORIGINAL_PATH"
        unset _ORIGINAL_PATH
    fi
    
    echo -e "${GREEN}✅ EAS 독립 환경이 비활성화되었습니다.${NC}"
    echo "원본 환경으로 복원되었습니다."
    
    # 함수 자체를 제거 (중복 호출 방지)
    unset -f deactivate_eas_env
}

# deactivate 함수를 export (서브쉘에서도 사용 가능하도록)
export -f deactivate_eas_env

#!/bin/bash

# CSR 파일 생성 스크립트
# 사용법: ./01.csr-create.sh <이름> <이메일> [출력디렉토리]
#
# 예시:
#   ./01.csr-create.sh cicddevdist minsu.rob@gmail.com
#   ./01.csr-create.sh mycert user@example.com ./output

set -euo pipefail

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 인자 확인
if [ $# -lt 2 ]; then
    echo -e "${RED}사용법: $0 <이름> <이메일> [출력디렉토리]${NC}"
    echo ""
    echo "예시:"
    echo "  $0 cicddevdist minsu.rob@gmail.com"
    echo "  $0 mycert user@example.com ./output"
    exit 1
fi

CERT_NAME="$1"
EMAIL="$2"
OUTPUT_DIR="${3:-$(dirname "$0")}"

# 출력 디렉토리 생성
mkdir -p "$OUTPUT_DIR"

# 파일 경로
CSR_FILE="$OUTPUT_DIR/$CERT_NAME.certSigningRequest"
KEY_FILE="$OUTPUT_DIR/$CERT_NAME.key"

# 기존 파일 확인
if [ -f "$CSR_FILE" ] || [ -f "$KEY_FILE" ]; then
    echo -e "${YELLOW}⚠️  기존 파일이 존재합니다:${NC}"
    [ -f "$CSR_FILE" ] && echo "  - $CSR_FILE"
    [ -f "$KEY_FILE" ] && echo "  - $KEY_FILE"
    echo ""
    read -p "덮어쓰시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}취소되었습니다.${NC}"
        exit 0
    fi
fi

echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${GREEN}  CSR 파일 생성${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo "이름 (Common Name): $CERT_NAME"
echo "이메일: $EMAIL"
echo "출력 디렉토리: $OUTPUT_DIR"
echo ""

# CSR 파일 생성
echo -e "${YELLOW}CSR 파일 생성 중...${NC}"
openssl req -new -newkey rsa:2048 -nodes \
    -keyout "$KEY_FILE" \
    -out "$CSR_FILE" \
    -subj "/CN=$CERT_NAME/emailAddress=$EMAIL"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ CSR 파일 생성 완료${NC}"
    echo ""
    echo "생성된 파일:"
    echo "  - CSR: $CSR_FILE"
    echo "  - Key: $KEY_FILE"
    echo ""
    echo -e "${YELLOW}다음 단계:${NC}"
    echo "1. Apple Developer Portal 접속: https://developer.apple.com/account/resources/certificates/list"
    echo "2. '+' 버튼 클릭하여 새 인증서 생성"
    echo "3. 'Apple Distribution' 선택"
    echo "4. 위의 CSR 파일($CSR_FILE) 업로드"
    echo "5. 다운로드한 인증서를 Keychain에 설치"
else
    echo -e "${RED}❌ CSR 파일 생성 실패${NC}"
    exit 1
fi

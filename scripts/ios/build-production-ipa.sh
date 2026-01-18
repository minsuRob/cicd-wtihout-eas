#!/bin/bash

# iOS Production IPA 빌드 스크립트 (일반화 버전)
# 2026년 기준 최신 Xcode 빌드 자동화 방법 사용
# 
# 사용법:
#   ./build-production-ipa.sh [옵션]
#
# 옵션:
#   --config-path <path>     설정 파일 경로 (기본: scripts/ios/config.js 또는 app.json)
#   --project-name <name>    프로젝트 이름 (기본: app.json에서 읽음)
#   --xcode-project <name>   Xcode 프로젝트/워크스페이스 이름 (기본: 프로젝트 이름과 동일)

set -euo pipefail

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 인자 파싱
CONFIG_PATH=""
PROJECT_NAME=""
XCODE_PROJECT_NAME=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --config-path)
            CONFIG_PATH="$2"
            shift 2
            ;;
        --project-name)
            PROJECT_NAME="$2"
            shift 2
            ;;
        --xcode-project)
            XCODE_PROJECT_NAME="$2"
            shift 2
            ;;
        -h|--help)
            echo "iOS Production IPA 빌드 스크립트"
            echo ""
            echo "사용법: $0 [옵션]"
            echo ""
            echo "옵션:"
            echo "  --config-path <path>     설정 파일 경로"
            echo "  --project-name <name>    프로젝트 이름"
            echo "  --xcode-project <name>   Xcode 프로젝트/워크스페이스 이름"
            echo "  -h, --help              이 도움말 표시"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ 알 수 없는 옵션: $1${NC}"
            exit 1
            ;;
    esac
done

# 프로젝트 경로 설정
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
IOS_DIR="$PROJECT_ROOT/ios"
CREDENTIALS_DIR="${CREDENTIALS_DIR:-$PROJECT_ROOT/credentials/ios/production}"
BUILD_DIR="$PROJECT_ROOT/build/ios/production"
ARCHIVE_DIR="$HOME/Library/Developer/Xcode/Archives"
APP_JSON="$PROJECT_ROOT/app.json"

echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${GREEN}  iOS Production IPA 빌드 스크립트${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo "프로젝트 경로: $PROJECT_ROOT"
echo ""

# 설정 파일 경로 결정
if [ -z "$CONFIG_PATH" ]; then
    # 기본 설정 파일 경로 시도
    if [ -f "$SCRIPT_DIR/config.js" ]; then
        CONFIG_PATH="$SCRIPT_DIR/config.js"
    elif [ -f "$APP_JSON" ]; then
        CONFIG_PATH="$APP_JSON"
    else
        echo -e "${RED}❌ 설정 파일을 찾을 수 없습니다.${NC}"
        echo "   다음 중 하나를 제공하세요:"
        echo "   1. --config-path 옵션으로 설정 파일 경로 지정"
        echo "   2. scripts/ios/config.js 파일 생성"
        echo "   3. 프로젝트 루트에 app.json 파일 생성"
        exit 1
    fi
fi

# 0. Build Number 자동 증가
echo -e "${YELLOW}[0/7] Build Number 자동 증가 중...${NC}"
BUILD_NUMBER_UPDATED=false

if [ ! -f "$APP_JSON" ]; then
    echo -e "${YELLOW}⚠️  app.json을 찾을 수 없습니다. Build Number 증가를 건너뜁니다.${NC}"
else
    CURRENT_BUILD_NUMBER=$(node -e "
        const app = require('$APP_JSON');
        const buildNumber = app.expo?.ios?.buildNumber || '1';
        console.log(buildNumber);
    " 2>/dev/null || echo "1")
    
    NEW_BUILD_NUMBER=$(node -e "
        const current = parseInt('$CURRENT_BUILD_NUMBER') || 1;
        const next = current + 1;
        console.log(next.toString());
    " 2>/dev/null || echo "1")
    
    if [ "$CURRENT_BUILD_NUMBER" != "$NEW_BUILD_NUMBER" ]; then
        node -e "
            const fs = require('fs');
            const app = JSON.parse(fs.readFileSync('$APP_JSON', 'utf8'));
            if (!app.expo) app.expo = {};
            if (!app.expo.ios) app.expo.ios = {};
            app.expo.ios.buildNumber = '$NEW_BUILD_NUMBER';
            fs.writeFileSync('$APP_JSON', JSON.stringify(app, null, 2) + '\n');
        " 2>/dev/null
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Build Number 증가: $CURRENT_BUILD_NUMBER → $NEW_BUILD_NUMBER${NC}"
            BUILD_NUMBER_UPDATED=true
        else
            echo -e "${YELLOW}⚠️  Build Number 업데이트 실패. 현재 값($CURRENT_BUILD_NUMBER)을 사용합니다.${NC}"
            NEW_BUILD_NUMBER="$CURRENT_BUILD_NUMBER"
        fi
    else
        echo -e "${GREEN}✅ Build Number: $CURRENT_BUILD_NUMBER (변경 없음)${NC}"
    fi
fi
echo ""

# 1. 설정 파일에서 환경 변수 로드
echo -e "${YELLOW}[1/7] 환경 변수 로드 중...${NC}"
if [ ! -f "$CONFIG_PATH" ]; then
    echo -e "${RED}❌ 설정 파일을 찾을 수 없습니다: $CONFIG_PATH${NC}"
    exit 1
fi

# 설정 파일에서 정보 추출
cd "$PROJECT_ROOT"
ENV_JSON=$(node -e "
const configPath = '$CONFIG_PATH';
let config;
try {
    config = require(configPath);
} catch (e) {
    console.error('설정 파일 로드 실패:', e.message);
    process.exit(1);
}

// app.json 또는 config.js 형식 모두 지원
const expo = config.expo || config || {};
const ios = expo.ios || {};

console.log(JSON.stringify({
    bundleIdentifier: ios.bundleIdentifier || expo.iosBundleIdentifier || '',
    appleTeamId: ios.appleTeamId || expo.appleTeamId || '',
    buildNumber: ios.buildNumber || expo.iosBuildNumber || '1',
    version: expo.version || config.version || '1.0.0',
    scheme: ios.scheme || expo.scheme || '',
    name: expo.name || config.name || ''
}));
" 2>/dev/null)

if [ -z "$ENV_JSON" ]; then
    echo -e "${RED}❌ 설정 파일에서 정보를 읽을 수 없습니다: $CONFIG_PATH${NC}"
    exit 1
fi

BUNDLE_ID=$(echo "$ENV_JSON" | node -e "const data = JSON.parse(require('fs').readFileSync(0, 'utf-8')); console.log(data.bundleIdentifier || '');")
TEAM_ID=$(echo "$ENV_JSON" | node -e "const data = JSON.parse(require('fs').readFileSync(0, 'utf-8')); console.log(data.appleTeamId || '');")
BUILD_NUMBER=$(echo "$ENV_JSON" | node -e "const data = JSON.parse(require('fs').readFileSync(0, 'utf-8')); console.log(data.buildNumber || '1');")
APP_VERSION=$(echo "$ENV_JSON" | node -e "const data = JSON.parse(require('fs').readFileSync(0, 'utf-8')); console.log(data.version || '1.0.0');")
SCHEME=$(echo "$ENV_JSON" | node -e "const data = JSON.parse(require('fs').readFileSync(0, 'utf-8')); console.log(data.scheme || '');")
APP_NAME=$(echo "$ENV_JSON" | node -e "const data = JSON.parse(require('fs').readFileSync(0, 'utf-8')); console.log(data.name || '');")

# 프로젝트 이름 결정
if [ -z "$PROJECT_NAME" ]; then
    PROJECT_NAME="$APP_NAME"
fi

if [ -z "$XCODE_PROJECT_NAME" ]; then
    XCODE_PROJECT_NAME="$PROJECT_NAME"
fi

# 필수 값 검증
if [ -z "$BUNDLE_ID" ] || [ -z "$TEAM_ID" ] || [ -z "$XCODE_PROJECT_NAME" ]; then
    echo -e "${RED}❌ 필수 설정이 누락되었습니다:${NC}"
    echo "   Bundle ID: ${BUNDLE_ID:-<없음>}"
    echo "   Team ID: ${TEAM_ID:-<없음>}"
    echo "   프로젝트 이름: ${XCODE_PROJECT_NAME:-<없음>}"
    echo ""
    echo "   설정 파일($CONFIG_PATH)에 다음 정보가 필요합니다:"
    echo "   - bundleIdentifier (expo.ios.bundleIdentifier)"
    echo "   - appleTeamId (expo.ios.appleTeamId)"
    echo "   - name (expo.name 또는 프로젝트 이름)"
    exit 1
fi

echo -e "${GREEN}✅ 환경 변수 로드 완료${NC}"
echo "   Bundle ID: $BUNDLE_ID"
echo "   Team ID: $TEAM_ID"
echo "   Version: ${APP_VERSION:-1.0.0}"
echo "   Build Number: ${BUILD_NUMBER:-1}"
echo "   Scheme: ${SCHEME:-$XCODE_PROJECT_NAME}"
echo "   Xcode 프로젝트: $XCODE_PROJECT_NAME"
echo ""

# Scheme이 없으면 프로젝트 이름 사용
if [ -z "$SCHEME" ]; then
    SCHEME="$XCODE_PROJECT_NAME"
fi

# 2. 필수 파일 확인
echo -e "${YELLOW}[2/7] 필수 파일 확인 중...${NC}"

# Provisioning Profile 확인
PROFILE_PATH=$(find "$CREDENTIALS_DIR" -name "*.mobileprovision" -type f | head -1)
if [ -z "$PROFILE_PATH" ]; then
    echo -e "${RED}❌ Provisioning Profile을 찾을 수 없습니다: $CREDENTIALS_DIR${NC}"
    echo ""
    echo "💡 Provisioning Profile 설정 방법:"
    echo "   1. Apple Developer Portal에서 App Store Distribution Profile 다운로드"
    echo "   2. 다음 경로에 저장: $CREDENTIALS_DIR/<프로파일명>.mobileprovision"
    echo ""
    echo "   또는 환경 변수로 경로 지정:"
    echo "   export CREDENTIALS_DIR=/path/to/credentials"
    exit 1
fi

echo -e "${GREEN}✅ Provisioning Profile: $(basename "$PROFILE_PATH")${NC}"

# iOS 프로젝트 확인 및 prebuild
XCODE_PROJECT_PATH="$IOS_DIR/$XCODE_PROJECT_NAME.xcodeproj"
XCODE_WORKSPACE_PATH="$IOS_DIR/$XCODE_PROJECT_NAME.xcworkspace"

if [ ! -d "$IOS_DIR" ] || ([ ! -d "$XCODE_PROJECT_PATH" ] && [ ! -d "$XCODE_WORKSPACE_PATH" ]); then
    echo -e "${YELLOW}⚠️  iOS 프로젝트가 없습니다. prebuild를 실행합니다...${NC}"
    cd "$PROJECT_ROOT"
    npx expo prebuild --platform ios --clean || {
        echo -e "${RED}❌ prebuild 실패. Xcode 프로젝트가 필요합니다.${NC}"
        exit 1
    }
elif [ "$BUILD_NUMBER_UPDATED" = true ]; then
    echo -e "${YELLOW}⚠️  Build Number가 변경되었습니다. prebuild를 실행하여 Xcode 프로젝트에 반영합니다...${NC}"
    cd "$PROJECT_ROOT"
    npx expo prebuild --platform ios || true
fi

# prebuild 후 항상 버전 정보 및 Entitlements 업데이트
echo "prebuild 후 버전 정보 및 Entitlements 업데이트 중..."
if [ -f "$XCODE_PROJECT_PATH/project.pbxproj" ]; then
    sed -i '' "s/\(CURRENT_PROJECT_VERSION = \)[^;]*/\1${BUILD_NUMBER:-1}/g" "$XCODE_PROJECT_PATH/project.pbxproj" 2>/dev/null || true
    sed -i '' "s/\(MARKETING_VERSION = \)[^;]*/\1${APP_VERSION:-1.0.0}/g" "$XCODE_PROJECT_PATH/project.pbxproj" 2>/dev/null || true
fi

# Info.plist 경로 (일반적으로 프로젝트명과 동일한 디렉토리)
INFO_PLIST_PATH="$IOS_DIR/$XCODE_PROJECT_NAME/Info.plist"
if [ ! -f "$INFO_PLIST_PATH" ]; then
    # 대체 경로 시도
    INFO_PLIST_PATH=$(find "$IOS_DIR" -name "Info.plist" -path "*/$XCODE_PROJECT_NAME/*" -type f | head -1)
fi

if [ -f "$INFO_PLIST_PATH" ]; then
    # CFBundleShortVersionString을 $(MARKETING_VERSION)로 설정
    if ! grep -q "\$(MARKETING_VERSION)" "$INFO_PLIST_PATH" 2>/dev/null; then
        sed -i '' '/<key>CFBundleShortVersionString<\/key>/,/<\/string>/s/<string>[^<]*<\/string>/<string>$(MARKETING_VERSION)<\/string>/' "$INFO_PLIST_PATH" 2>/dev/null || true
    fi
    
    # CFBundleVersion을 $(CURRENT_PROJECT_VERSION)로 설정
    if ! grep -q "\$(CURRENT_PROJECT_VERSION)" "$INFO_PLIST_PATH" 2>/dev/null; then
        sed -i '' '/<key>CFBundleVersion<\/key>/,/<\/string>/s/<string>[^<]*<\/string>/<string>$(CURRENT_PROJECT_VERSION)<\/string>/' "$INFO_PLIST_PATH" 2>/dev/null || true
    fi
fi

# Entitlements 파일 확인 및 업데이트
ENTITLEMENTS_FILE="$IOS_DIR/$XCODE_PROJECT_NAME/$XCODE_PROJECT_NAME.entitlements"
if [ ! -f "$ENTITLEMENTS_FILE" ]; then
    ENTITLEMENTS_FILE=$(find "$IOS_DIR" -name "*.entitlements" -path "*/$XCODE_PROJECT_NAME/*" -type f | head -1)
fi

if [ -f "$ENTITLEMENTS_FILE" ]; then
    CURRENT_APS_ENV=$(plutil -extract aps-environment raw "$ENTITLEMENTS_FILE" 2>/dev/null || echo "")
    if [ "$CURRENT_APS_ENV" != "production" ]; then
        plutil -replace aps-environment -string "production" "$ENTITLEMENTS_FILE" 2>/dev/null || true
        echo -e "${GREEN}✅ Entitlements 파일 업데이트 완료${NC}"
    fi
fi

if [ ! -d "$XCODE_PROJECT_PATH" ] && [ ! -d "$XCODE_WORKSPACE_PATH" ]; then
    echo -e "${RED}❌ iOS 프로젝트를 찾을 수 없습니다: $IOS_DIR${NC}"
    exit 1
fi

echo -e "${GREEN}✅ 모든 필수 파일 확인 완료${NC}"
echo ""

# 3. iOS 프로젝트 준비
echo -e "${YELLOW}[3/7] iOS 프로젝트 준비 중...${NC}"
cd "$IOS_DIR"

USE_WORKSPACE=false
if [ -d "$XCODE_WORKSPACE_PATH" ]; then
    USE_WORKSPACE=true
    echo -e "${GREEN}✅ Workspace 사용: $XCODE_WORKSPACE_PATH${NC}"
elif [ -d "$XCODE_PROJECT_PATH" ]; then
    USE_WORKSPACE=false
    echo -e "${GREEN}✅ Project 사용: $XCODE_PROJECT_PATH${NC}"
else
    echo -e "${RED}❌ Xcode 프로젝트를 찾을 수 없습니다.${NC}"
    exit 1
fi

# CocoaPods 설치 (Podfile이 있는 경우)
if [ -f "Podfile" ]; then
    PODFILE_BACKUP="$IOS_DIR/Podfile.backup"
    cp "$IOS_DIR/Podfile" "$PODFILE_BACKUP"
    
    # expo-dev-menu-interface 제외 로직 (기존 코드와 동일)
    python3 - "$IOS_DIR/Podfile" <<'PYTHON_SCRIPT'
import re
import sys
import os

podfile_path = sys.argv[1] if len(sys.argv) > 1 else 'Podfile'
with open(podfile_path, 'r') as f:
    content = f.read()

has_exclusion = 'expo-dev-menu-interface' in content and 'EXCLUDED_ARCHS' in content

if not has_exclusion:
    exclusion_code = '''    # 프로덕션 빌드에서 expo-dev-menu-interface 타겟 완전 제외
    installer.pods_project.targets.each do |target|
      if target.name == 'expo-dev-menu-interface'
        target.build_configurations.each do |config|
          if config.name == 'Release'
            config.build_settings['EXCLUDED_ARCHS[sdk=iphoneos*]'] = 'arm64 armv7 armv7s'
            config.build_settings['VALID_ARCHS'] = ''
            config.build_settings['ONLY_ACTIVE_ARCH'] = 'NO'
            config.build_settings['SKIP_INSTALL'] = 'YES'
            config.build_settings['SWIFT_EMIT_MODULE_INTERFACE'] = 'NO'
            config.build_settings['SWIFT_VERIFY_EMITTED_MODULE_INTERFACE'] = 'NO'
            config.build_settings['ENABLE_BITCODE'] = 'NO'
            config.build_settings['CODE_SIGNING_REQUIRED'] = 'NO'
            config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
            config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] = '$(inherited) EXCLUDE_FROM_BUILD=1'
            config.build_settings['ENABLE_APP_INTENTS'] = 'NO'
            config.build_settings['ENABLE_APP_INTENTS_METADATA'] = 'NO'
          end
        end
        target.build_phases.each do |phase|
          begin
            phase_name = phase.respond_to?(:display_name) ? phase.display_name.to_s : phase.class.name.to_s
            if phase_name.include?('ExtractAppIntentsMetadata') || 
               phase_name.include?('SwiftVerifyEmittedModuleInterface')
              phase.remove_from_project
            end
          rescue => e
          end
        end
        target.build_configurations.each do |config|
          if config.name == 'Release'
            config.build_settings['ONLY_ACTIVE_ARCH'] = 'NO'
            config.build_settings['EXCLUDED_ARCHS'] = 'arm64 armv7 armv7s'
            config.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = '$(inherited) EXCLUDE_FROM_BUILD'
            config.build_settings['OTHER_SWIFT_FLAGS'] = '$(inherited) -Xfrontend -disable-implicit-concurrency-module-import'
          end
        end
      end
    end
'''
    
    pattern = r'(react_native_post_install\([^)]+\)\s*\)\s*)(\n\s*end)'
    
    def add_exclusion(match):
        return match.group(1) + '\n' + exclusion_code + match.group(2)
    
    new_content = re.sub(pattern, add_exclusion, content, flags=re.DOTALL)
    
    if new_content == content:
        lines = content.split('\n')
        new_lines = []
        i = 0
        found_react_native = False
        paren_count = 0
        
        while i < len(lines):
            line = lines[i]
            new_lines.append(line)
            
            if 'react_native_post_install(' in line:
                found_react_native = True
                paren_count += line.count('(') - line.count(')')
            elif found_react_native:
                paren_count += line.count('(') - line.count(')')
                if paren_count == 0 and ')' in line:
                    if i + 1 < len(lines):
                        next_line = lines[i + 1].strip()
                        if next_line == 'end' or next_line == '':
                            new_lines.append(exclusion_code)
                            found_react_native = False
            
            i += 1
        
        if found_react_native or new_content == content:
            new_content = '\n'.join(new_lines)
    
    if new_content != content:
        with open(podfile_path, 'w') as f:
            f.write(new_content)
        print("✅ Podfile에 expo-dev-menu-interface 제외 로직 추가됨")
PYTHON_SCRIPT
    
    echo "CocoaPods 의존성 설치 중..."
    pod install --repo-update 2>&1 | grep -v "^$" || true
    echo -e "${GREEN}✅ CocoaPods 설치 완료${NC}"
    
    if [ -f "$PODFILE_BACKUP" ]; then
        mv "$PODFILE_BACKUP" "$IOS_DIR/Podfile"
    fi
else
    echo -e "${YELLOW}⚠️  Podfile이 없습니다. 건너뜁니다.${NC}"
fi
echo ""

# 4. Provisioning Profile 설치
echo -e "${YELLOW}[4/7] Provisioning Profile 설치 중...${NC}"

PROFILE_UUID=$(security cms -D -i "$PROFILE_PATH" 2>/dev/null | plutil -p - | grep -E '^\s*"UUID"' | sed 's/.*"UUID"[^"]*"\([^"]*\)".*/\1/' || echo "")
PROFILE_NAME=$(security cms -D -i "$PROFILE_PATH" 2>/dev/null | plutil -p - | grep -E '^\s*"Name"' | sed 's/.*"Name"[^"]*"\([^"]*\)".*/\1/' || echo "")

if [ -z "$PROFILE_UUID" ]; then
    echo -e "${RED}❌ Provisioning Profile UUID를 추출할 수 없습니다.${NC}"
    exit 1
fi

PROVISIONING_PROFILES_DIR="$HOME/Library/MobileDevice/Provisioning Profiles"
mkdir -p "$PROVISIONING_PROFILES_DIR"
INSTALLED_PROFILE_PATH="$PROVISIONING_PROFILES_DIR/$PROFILE_UUID.mobileprovision"
cp "$PROFILE_PATH" "$INSTALLED_PROFILE_PATH"

if [ -n "$PROFILE_NAME" ]; then
    PROFILE_SPECIFIER="$PROFILE_NAME"
    echo -e "${GREEN}✅ Provisioning Profile Name: $PROFILE_SPECIFIER${NC}"
else
    PROFILE_SPECIFIER="$PROFILE_UUID"
    echo -e "${GREEN}✅ Provisioning Profile UUID: $PROFILE_SPECIFIER${NC}"
fi

echo -e "${GREEN}✅ Provisioning Profile 설치 완료${NC}"
echo ""

# 5. Code Signing Identity 확인
echo -e "${YELLOW}[5/7] Code Signing Identity 확인 중...${NC}"

CODE_SIGN_IDENTITY="Apple Distribution"
CERT_IDENTITY_FULL=$(security find-identity -v -p codesigning 2>/dev/null | grep "$CODE_SIGN_IDENTITY.*$TEAM_ID" | head -1 | sed 's/.*"\([^"]*\)".*/\1/' || echo "")

if [ -z "$CERT_IDENTITY_FULL" ]; then
    echo -e "${RED}❌ Keychain에서 '$CODE_SIGN_IDENTITY' (Team: $TEAM_ID) 인증서를 찾을 수 없습니다.${NC}"
    echo ""
    echo "💡 인증서가 없다면:"
    echo "   1. Apple Developer Portal에서 Distribution Certificate를 다운로드"
    echo "   2. Keychain에 설치 (더블클릭 또는 security import 명령)"
    exit 1
fi

echo -e "${GREEN}✅ Code Sign Identity: $CERT_IDENTITY_FULL${NC}"
echo ""

# 5.5. 버전 정보 업데이트
echo -e "${YELLOW}[5.5/7] 버전 정보 업데이트 중...${NC}"

if [ -f "$XCODE_PROJECT_PATH/project.pbxproj" ]; then
    sed -i '' "s/CURRENT_PROJECT_VERSION = [^;]*/CURRENT_PROJECT_VERSION = ${BUILD_NUMBER:-1}/g" "$XCODE_PROJECT_PATH/project.pbxproj" 2>/dev/null || true
    sed -i '' "s/MARKETING_VERSION = [^;]*/MARKETING_VERSION = ${APP_VERSION:-1.0.0}/g" "$XCODE_PROJECT_PATH/project.pbxproj" 2>/dev/null || true
    echo -e "${GREEN}✅ project.pbxproj 업데이트 완료${NC}"
fi

if [ -f "$INFO_PLIST_PATH" ]; then
    HAS_VERSION_VAR=$(grep -c "\$(MARKETING_VERSION)" "$INFO_PLIST_PATH" 2>/dev/null || echo "0")
    HAS_BUILD_VAR=$(grep -c "\$(CURRENT_PROJECT_VERSION)" "$INFO_PLIST_PATH" 2>/dev/null || echo "0")
    
    if [ "$HAS_VERSION_VAR" -eq 0 ] || [ "$HAS_BUILD_VAR" -eq 0 ]; then
        if [ "$HAS_VERSION_VAR" -eq 0 ]; then
            sed -i '' '/<key>CFBundleShortVersionString<\/key>/{n;s/<string>.*<\/string>/<string>$(MARKETING_VERSION)<\/string>/;}' "$INFO_PLIST_PATH" 2>/dev/null || true
        fi
        if [ "$HAS_BUILD_VAR" -eq 0 ]; then
            sed -i '' '/<key>CFBundleVersion<\/key>/{n;s/<string>.*<\/string>/<string>$(CURRENT_PROJECT_VERSION)<\/string>/;}' "$INFO_PLIST_PATH" 2>/dev/null || true
        fi
        echo -e "${GREEN}✅ Info.plist 변수 참조 설정 완료${NC}"
    else
        echo -e "${GREEN}✅ Info.plist 변수 참조가 이미 설정되어 있습니다${NC}"
    fi
fi

echo "   Version: ${APP_VERSION:-1.0.0}"
echo "   Build Number: ${BUILD_NUMBER:-1}"
echo ""

# 6. Archive 생성
echo -e "${YELLOW}[6/7] Archive 생성 중...${NC}"

ARCHIVE_DATE=$(date +"%Y-%m-%d_%H-%M-%S")
ARCHIVE_NAME="$PROJECT_NAME-Production-$ARCHIVE_DATE"
ARCHIVE_PATH="$ARCHIVE_DIR/$ARCHIVE_NAME.xcarchive"

mkdir -p "$ARCHIVE_DIR"
mkdir -p "$BUILD_DIR"

# Archive 생성 직전 버전 정보 최종 확인 및 업데이트
if [ -f "$XCODE_PROJECT_PATH/project.pbxproj" ]; then
    sed -i '' "s/\(CURRENT_PROJECT_VERSION = \)[^;]*/\1${BUILD_NUMBER:-1}/g" "$XCODE_PROJECT_PATH/project.pbxproj" 2>/dev/null || true
    sed -i '' "s/\(MARKETING_VERSION = \)[^;]*/\1${APP_VERSION:-1.0.0}/g" "$XCODE_PROJECT_PATH/project.pbxproj" 2>/dev/null || true
fi

echo "xcodebuild archive 실행 중..."
if [ "$USE_WORKSPACE" = true ]; then
    xcodebuild archive \
        -workspace "$XCODE_WORKSPACE_PATH" \
        -scheme "$SCHEME" \
        -configuration Release \
        -sdk iphoneos \
        -archivePath "$ARCHIVE_PATH" \
        -destination "generic/platform=iOS" \
        -skipPackagePluginValidation \
        ONLY_ACTIVE_ARCH=NO \
        CODE_SIGN_STYLE="Manual" \
        CODE_SIGN_IDENTITY="$CODE_SIGN_IDENTITY" \
        DEVELOPMENT_TEAM="$TEAM_ID" \
        PROVISIONING_PROFILE_SPECIFIER="$PROFILE_SPECIFIER" \
        MARKETING_VERSION="${APP_VERSION:-1.0.0}" \
        CURRENT_PROJECT_VERSION="${BUILD_NUMBER:-1}" \
        SKIP_INSTALL=NO \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        ENABLE_BITCODE=NO \
        2>&1 | tee "$BUILD_DIR/archive.log" || ARCHIVE_EXIT_CODE=$?
else
    xcodebuild archive \
        -project "$XCODE_PROJECT_PATH" \
        -scheme "$SCHEME" \
        -configuration Release \
        -sdk iphoneos \
        -archivePath "$ARCHIVE_PATH" \
        -destination "generic/platform=iOS" \
        -skipPackagePluginValidation \
        ONLY_ACTIVE_ARCH=NO \
        CODE_SIGN_STYLE="Manual" \
        CODE_SIGN_IDENTITY="$CODE_SIGN_IDENTITY" \
        DEVELOPMENT_TEAM="$TEAM_ID" \
        PROVISIONING_PROFILE_SPECIFIER="$PROFILE_SPECIFIER" \
        MARKETING_VERSION="${APP_VERSION:-1.0.0}" \
        CURRENT_PROJECT_VERSION="${BUILD_NUMBER:-1}" \
        SKIP_INSTALL=NO \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        ENABLE_BITCODE=NO \
        2>&1 | tee "$BUILD_DIR/archive.log" || ARCHIVE_EXIT_CODE=$?
fi

sleep 3

XCODE_ARCHIVES_DIR="$HOME/Library/Developer/Xcode/Archives"
LATEST_ARCHIVE_IN_XCODE=$(find "$XCODE_ARCHIVES_DIR" -name "*${PROJECT_NAME}*.xcarchive" -type d -maxdepth 2 2>/dev/null | sort -r | head -1)

if [ ! -d "$ARCHIVE_PATH" ]; then
    if [ "${ARCHIVE_EXIT_CODE:-0}" -ne 0 ]; then
        HAS_EXTRACT_ERROR=$(grep -c "ExtractAppIntentsMetadata.*expo-dev-menu-interface" "$BUILD_DIR/archive.log" 2>/dev/null || echo "0")
        
        if [ "$HAS_EXTRACT_ERROR" -gt 0 ] && [ -n "$LATEST_ARCHIVE_IN_XCODE" ] && [ -d "$LATEST_ARCHIVE_IN_XCODE" ]; then
            ARCHIVE_PATH="$LATEST_ARCHIVE_IN_XCODE"
            echo -e "${GREEN}✅ Archive가 생성되었습니다 (경로: $ARCHIVE_PATH)${NC}"
            echo -e "${YELLOW}⚠️  ExtractAppIntentsMetadata 오류는 무시되었습니다.${NC}"
        else
            echo -e "${RED}❌ Archive 빌드 실패. 전체 로그는 $BUILD_DIR/archive.log를 확인하세요.${NC}"
            exit 1
        fi
    else
        echo -e "${RED}❌ Archive 생성 실패${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✅ Archive 생성 완료: $ARCHIVE_PATH${NC}"

# Archive 내부 Info.plist 버전 정보 확인 및 업데이트
ARCHIVE_APP_DIR=$(find "$ARCHIVE_PATH/Products/Applications" -name "*.app" -type d 2>/dev/null | head -1)
ARCHIVE_INFO_PLIST="$ARCHIVE_APP_DIR/Info.plist"

if [ -f "$ARCHIVE_INFO_PLIST" ]; then
    CURRENT_ARCHIVE_VERSION=$(plutil -extract CFBundleShortVersionString raw "$ARCHIVE_INFO_PLIST" 2>/dev/null || echo "")
    CURRENT_ARCHIVE_BUILD=$(plutil -extract CFBundleVersion raw "$ARCHIVE_INFO_PLIST" 2>/dev/null || echo "")
    echo "Archive 내부 버전 정보 확인: Version=$CURRENT_ARCHIVE_VERSION, Build=$CURRENT_ARCHIVE_BUILD"
    
    if [ "$CURRENT_ARCHIVE_BUILD" != "${BUILD_NUMBER:-1}" ] || [ "$CURRENT_ARCHIVE_VERSION" != "${APP_VERSION:-1.0.0}" ]; then
        echo "   버전 정보 업데이트 필요: 목표 Version=${APP_VERSION:-1.0.0}, Build=${BUILD_NUMBER:-1}"
        echo "   Archive 내부 Info.plist 업데이트 중 (Export 과정에서 재서명됨)..."
        
        plutil -replace CFBundleShortVersionString -string "${APP_VERSION:-1.0.0}" "$ARCHIVE_INFO_PLIST" 2>/dev/null || true
        plutil -replace CFBundleVersion -string "${BUILD_NUMBER:-1}" "$ARCHIVE_INFO_PLIST" 2>/dev/null || true
        
        UPDATED_VERSION=$(plutil -extract CFBundleShortVersionString raw "$ARCHIVE_INFO_PLIST" 2>/dev/null || echo "")
        UPDATED_BUILD=$(plutil -extract CFBundleVersion raw "$ARCHIVE_INFO_PLIST" 2>/dev/null || echo "")
        echo "   업데이트 후: Version=$UPDATED_VERSION, Build=$UPDATED_BUILD"
        
        if [ "$UPDATED_BUILD" = "${BUILD_NUMBER:-1}" ] && [ "$UPDATED_VERSION" = "${APP_VERSION:-1.0.0}" ]; then
            echo -e "${GREEN}✅ Archive 내부 Info.plist 버전 정보 업데이트 완료${NC}"
            echo -e "${YELLOW}⚠️  주의: Archive 내부 Info.plist가 수정되었습니다. Export 과정에서 재서명됩니다.${NC}"
        fi
    else
        echo -e "${GREEN}✅ Archive 내부 버전 정보가 이미 올바릅니다${NC}"
    fi
fi
echo ""

# 7. IPA Export
echo -e "${YELLOW}[7/7] IPA Export 중...${NC}"

EXPORT_OPTIONS_PLIST="$BUILD_DIR/ExportOptions-production.plist"

cat > "$EXPORT_OPTIONS_PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>teamID</key>
    <string>$TEAM_ID</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>$CERT_IDENTITY_FULL</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>$BUNDLE_ID</key>
        <string>$PROFILE_SPECIFIER</string>
    </dict>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>thinning</key>
    <string>&lt;none&gt;</string>
    <key>manageAppVersionAndBuildNumber</key>
    <false/>
</dict>
</plist>
EOF

xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
    -exportPath "$BUILD_DIR" \
    2>&1 | tee "$BUILD_DIR/export.log" || {
    echo -e "${RED}❌ IPA Export 실패. 전체 로그는 $BUILD_DIR/export.log를 확인하세요.${NC}"
    exit 1
}

echo -e "${GREEN}✅ IPA Export 완료${NC}"
echo ""

# 8. 결과 확인
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${GREEN}  빌드 결과${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"

IPA_FILE="$BUILD_DIR/$SCHEME.ipa"
if [ -f "$IPA_FILE" ]; then
    IPA_SIZE=$(du -h "$IPA_FILE" | cut -f1)
    echo -e "${GREEN}✅ 빌드 성공!${NC}"
    echo ""
    echo "📦 빌드 결과:"
    echo "   IPA 파일: $IPA_FILE ($IPA_SIZE)"
    echo "   Archive: $ARCHIVE_PATH"
    echo ""
    echo "📱 App Store Connect 업로드 방법:"
    echo "   1. Transporter 앱 사용 (권장):"
    echo "      - Transporter 앱을 열고 IPA 파일을 드래그 앤 드롭"
    echo ""
    echo "   2. 명령줄 사용 (API Key 필요):"
    echo "      xcrun altool --upload-app --type ios --file \"$IPA_FILE\" \\"
    echo "        --apiKey <API_KEY> --apiIssuer <ISSUER_ID>"
    echo ""
    echo "   3. Xcode Organizer 사용:"
    echo "      Xcode > Window > Organizer > Archives > Distribute App"
    echo ""
else
    echo -e "${YELLOW}⚠️  IPA 파일을 찾을 수 없습니다.${NC}"
    echo "   Archive 위치: $ARCHIVE_PATH"
    echo "   Export 로그: $BUILD_DIR/export.log"
    exit 1
fi

echo ""
echo -e "${GREEN}=== Production 빌드 완료 ===${NC}"

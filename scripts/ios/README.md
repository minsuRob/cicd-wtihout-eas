# iOS Production IPA 빌드 스크립트

Expo 프로젝트를 위한 iOS Production IPA 자동 빌드 스크립트입니다. EAS Build 없이 로컬에서 또는 CI/CD에서 사용할 수 있습니다.

## 📋 목차

- [필요 조건](#필요-조건)
- [설치 및 설정](#설치-및-설정)
- [사용 방법](#사용-방법)
- [필요한 파일](#필요한-파일)
- [인증서 및 Provisioning Profile 발급 절차](#인증서-및-provisioning-profile-발급-절차)
- [디렉토리 구조](#디렉토리-구조)
- [문제 해결](#문제-해결)

## 필요 조건

- macOS (Xcode 필수)
- Node.js (v14 이상)
- Expo CLI
- CocoaPods
- Apple Developer 계정

## 설치 및 설정

### 1. 스크립트 실행 권한 부여

```bash
chmod +x scripts/ios/build-production-ipa.sh
```

### 2. 설정 파일 준비

프로젝트 루트에 `app.json`이 있으면 자동으로 사용됩니다. 또는 `scripts/ios/config.js` 파일을 생성하여 설정할 수 있습니다.

#### app.json 예제

```json
{
  "expo": {
    "name": "MyApp",
    "version": "1.0.0",
    "ios": {
      "bundleIdentifier": "com.example.myapp",
      "appleTeamId": "YOUR_TEAM_ID",
      "buildNumber": "1"
    }
  }
}
```

#### config.js 예제

```javascript
module.exports = {
  expo: {
    name: "MyApp",
    version: "1.0.0",
    ios: {
      bundleIdentifier: "com.example.myapp",
      appleTeamId: "YOUR_TEAM_ID",
      buildNumber: "1"
    }
  }
};
```

### 3. Credentials 준비

`credentials/ios/production/` 디렉토리에 다음 파일이 필요합니다:

- `*.mobileprovision` - App Store Distribution Provisioning Profile

또는 환경 변수로 경로 지정:

```bash
export CREDENTIALS_DIR=/path/to/credentials
```

## 사용 방법

### 기본 사용법

```bash
./scripts/ios/build-production-ipa.sh
```

### 옵션 지정

```bash
# 설정 파일 경로 지정
./scripts/ios/build-production-ipa.sh --config-path /path/to/config.js

# 프로젝트 이름 지정
./scripts/ios/build-production-ipa.sh --project-name MyApp

# Xcode 프로젝트/워크스페이스 이름 지정
./scripts/ios/build-production-ipa.sh --xcode-project MyApp

# 여러 옵션 조합
./scripts/ios/build-production-ipa.sh \
  --project-name MyApp \
  --xcode-project MyApp \
  --config-path scripts/ios/config.js
```

### CI/CD에서 사용

```yaml
# GitHub Actions 예제
- name: Build iOS IPA
  run: |
    ./scripts/ios/build-production-ipa.sh
  env:
    CREDENTIALS_DIR: ${{ secrets.CREDENTIALS_DIR }}
```

## 필요한 파일

빌드를 성공적으로 완료하려면 다음 파일들이 필요합니다:

### 필수 파일

1. **Provisioning Profile** (`*.mobileprovision`)
   - 위치: `credentials/ios/production/` 또는 `CREDENTIALS_DIR` 환경 변수로 지정
   - 유형: App Store Distribution
   - Bundle ID가 프로젝트와 일치해야 함

2. **Distribution Certificate** (Keychain에 설치)
   - 유형: Apple Distribution
   - Team ID가 설정 파일의 `appleTeamId`와 일치해야 함

3. **설정 파일** (`app.json` 또는 `config.js`)
   - 프로젝트 루트의 `app.json` 또는 `scripts/ios/config.js`
   - 필수 항목:
     - `bundleIdentifier` (expo.ios.bundleIdentifier)
     - `appleTeamId` (expo.ios.appleTeamId)
     - `name` (expo.name 또는 프로젝트 이름)

### 생성되는 파일

빌드 완료 후 다음 파일들이 생성됩니다:

- `build/ios/production/*.ipa` - 최종 IPA 파일
- `build/ios/production/ExportOptions-production.plist` - Export 옵션 파일
- `build/ios/production/archive.log` - Archive 빌드 로그
- `build/ios/production/export.log` - Export 로그
- `~/Library/Developer/Xcode/Archives/*.xcarchive` - Archive 파일

## 인증서 및 Provisioning Profile 발급 절차

### Apple Developer Portal URL

- **메인 포털**: https://developer.apple.com/account/
- **Certificates, Identifiers & Profiles**: https://developer.apple.com/account/resources/

### 1. Distribution Certificate 발급

1. **Apple Developer Portal 접속**
   - https://developer.apple.com/account/resources/certificates/list 접속
   - 로그인 후 "Certificates, Identifiers & Profiles" 섹션으로 이동

2. **Certificate 생성**
   - "+" 버튼 클릭하여 새 인증서 생성
   - "Apple Distribution" 선택
   - CSR 파일 생성 필요:
     ```bash
     # Keychain Access > Certificate Assistant > Request a Certificate From a Certificate Authority
     # 또는 명령줄:
     openssl req -new -newkey rsa:2048 -nodes -keyout private.key -out request.csr
     ```
   - 생성된 `.csr` 파일 업로드
   - 인증서 다운로드 (`.cer` 파일)

3. **Keychain에 설치**
   ```bash
   # 더블클릭하여 설치하거나:
   security import certificate.cer -k ~/Library/Keychains/login.keychain
   ```

### 2. App ID 등록

1. **Identifiers 섹션으로 이동**
   - https://developer.apple.com/account/resources/identifiers/list

2. **App ID 생성/확인**
   - "+" 버튼으로 새 App ID 생성 또는 기존 App ID 확인
   - Bundle ID 입력 (예: `com.example.myapp`)
   - 필요한 Capabilities 활성화 (Push Notifications, etc.)

### 3. Provisioning Profile 발급

1. **Profiles 섹션으로 이동**
   - https://developer.apple.com/account/resources/profiles/list

2. **Distribution Profile 생성**
   - "+" 버튼 클릭
   - "App Store" 선택 (TestFlight 및 App Store 배포용)
   - App ID 선택 (위에서 생성한 App ID)
   - Distribution Certificate 선택 (위에서 생성한 인증서)
   - Profile 이름 지정 (예: "MyApp App Store Distribution")
   - 생성 완료 후 다운로드

3. **프로젝트에 배치**
   ```bash
   # 다운로드한 .mobileprovision 파일을 credentials 디렉토리에 저장
   mkdir -p credentials/ios/production
   cp ~/Downloads/*.mobileprovision credentials/ios/production/
   ```

### 4. Entitlements 설정 확인

프로덕션 빌드의 경우 `ios/YourApp/YourApp.entitlements` 파일에서 다음을 확인하세요:

```xml
<key>aps-environment</key>
<string>production</string>
```

스크립트가 자동으로 `development`를 `production`으로 변경합니다.

## 디렉토리 구조

```
프로젝트 루트/
├── app.json                          # 설정 파일 (선택)
├── credentials/
│   └── ios/
│       └── production/
│           └── *.mobileprovision    # Provisioning Profile
├── scripts/
│   └── ios/
│       ├── build-production-ipa.sh  # 빌드 스크립트
│       ├── config.js                # 설정 파일 (선택)
│       └── README.md                # 이 문서
└── build/
    └── ios/
        └── production/
            └── *.ipa                # 생성된 IPA 파일
```

## 주요 기능

### ✅ 자동 Build Number 증가

- `app.json`의 `expo.ios.buildNumber`를 자동으로 증가시킵니다
- 빌드할 때마다 Build Number가 자동으로 1씩 증가

### ✅ 버전 정보 자동 관리

- `app.json`의 버전 정보를 Xcode 프로젝트에 자동 반영
- `Info.plist`의 `CFBundleVersion`과 `CFBundleShortVersionString`을 Xcode 빌드 변수로 설정
- Archive 생성 과정에서 버전 정보가 정확히 반영되도록 보장

### ✅ expo-dev-menu-interface 자동 제외

- 프로덕션 빌드에서 개발용 패키지(`expo-dev-menu-interface`) 자동 제외
- `ExtractAppIntentsMetadata` 오류 방지

### ✅ Entitlements 자동 업데이트

- `aps-environment`를 자동으로 `production`으로 설정

## 문제 해결

### 1. "Provisioning Profile을 찾을 수 없습니다"

**해결책:**
```bash
# Provisioning Profile이 올바른 위치에 있는지 확인
ls -la credentials/ios/production/

# 또는 환경 변수로 경로 지정
export CREDENTIALS_DIR=/path/to/credentials
./scripts/ios/build-production-ipa.sh
```

### 2. "Code Sign Identity를 찾을 수 없습니다"

**해결책:**
```bash
# Keychain에 Distribution Certificate가 설치되어 있는지 확인
security find-identity -v -p codesigning

# 인증서가 없다면 Apple Developer Portal에서 다운로드 후 설치
# Keychain Access 앱에서 더블클릭하여 설치
```

### 3. "Archive 빌드 실패"

**해결책:**
- `build/ios/production/archive.log` 파일 확인
- 일반적인 원인:
  - Code Sign 설정 오류
  - Provisioning Profile의 Bundle ID 불일치
  - Xcode 프로젝트 설정 오류

### 4. "Info.plist를 찾을 수 없습니다"

**해결책:**
- `prebuild` 실행:
  ```bash
  npx expo prebuild --platform ios
  ```
- Xcode 프로젝트가 생성되었는지 확인:
  ```bash
  ls -la ios/
  ```

### 5. "ExtractAppIntentsMetadata 오류"

**해결책:**
- 이 오류는 `expo-dev-menu-interface` 관련 오류로, 일반적으로 무시해도 됩니다
- Archive가 성공적으로 생성되었다면 계속 진행됩니다
- 스크립트가 자동으로 처리하므로 수동 조작 불필요

## 참고 자료

### Apple 공식 문서

- **App Store Connect 가이드**: https://developer.apple.com/app-store-connect/
- **Code Signing 가이드**: https://developer.apple.com/documentation/xcode/managing-your-team-s-signing-assets
- **Provisioning Profiles**: https://developer.apple.com/documentation/xcode/managing-provisioning-profiles

### 유용한 URL

- **Apple Developer Portal**: https://developer.apple.com/account/
- **App Store Connect**: https://appstoreconnect.apple.com/
- **Transporter 앱 다운로드**: https://apps.apple.com/app/transporter/id1450874784
- **Xcode 다운로드**: https://developer.apple.com/xcode/

### 명령줄 도구

```bash
# Keychain의 인증서 확인
security find-identity -v -p codesigning

# Provisioning Profile 정보 확인
security cms -D -i profile.mobileprovision | plutil -p -

# IPA 파일 검증
codesign --verify --deep --strict --verbose=2 Payload/App.app

# Entitlements 확인
codesign -d --entitlements - Payload/App.app
```

## EAS 독립 세션 사용법 (Python 가상환경 스타일)

기존 EAS 로그인 환경에 영향을 주지 않고, 새로운 독립적인 세션에서 EAS CLI를 사용하고 싶을 때 사용할 수 있습니다. Python의 가상환경(venv)처럼 동작합니다.

### 방법 1: 대화형 세션 활성화 (권장)

독립 환경을 활성화하여 여러 EAS 명령을 연속으로 실행할 때 사용합니다:

```bash
# 독립 환경 활성화 (환경 이름: production)
source scripts/ios/eas-login-helper.sh production

# 이제 이 쉘에서 EAS 명령 사용
eas login
eas whoami
eas build:configure
eas build --platform ios

# 환경 종료
deactivate_eas_env
# 또는 단순히 exit
```

**다른 환경 이름으로 여러 세션 관리:**

```bash
# 프로덕션 환경
source scripts/ios/eas-login-helper.sh production
eas login
# ... 작업 ...
deactivate_eas_env

# 스테이징 환경
source scripts/ios/eas-login-helper.sh staging
eas login
# ... 작업 ...
deactivate_eas_env
```

### 방법 2: 단일 명령 실행

한 번의 EAS 명령만 실행할 때 사용합니다:

```bash
# 로그인
./scripts/ios/eas-env.sh production login

# 현재 사용자 확인
./scripts/ios/eas-env.sh production whoami

# 빌드 설정
./scripts/ios/eas-env.sh production build:configure

# 빌드 실행
./scripts/ios/eas-env.sh production build --platform ios
```

### 동작 원리

- **독립 환경 디렉토리**: `.eas-env/<환경이름>/` 디렉토리에 EAS 인증 정보 저장
- **HOME 환경 변수 임시 변경**: `HOME` 환경 변수를 독립 환경 디렉토리로 변경
- **기존 환경 보호**: 원본 `~/.expo/`와 `~/.eas/` 디렉토리는 그대로 유지

### 디렉토리 구조

```
프로젝트 루트/
├── .eas-env/                    # 독립 환경 디렉토리 (gitignore에 추가됨)
│   ├── production/              # 프로덕션 환경
│   │   ├── .expo/              # EAS 인증 정보
│   │   └── .eas/               # EAS 설정
│   └── staging/                # 스테이징 환경
│       ├── .expo/
│       └── .eas/
└── scripts/
    └── ios/
        ├── eas-login-helper.sh  # 대화형 세션 스크립트
        └── eas-env.sh          # 단일 명령 스크립트
```

### .gitignore 추가

`.eas-env/` 디렉토리는 자동으로 `.gitignore`에 추가되어야 합니다:

```bash
# .gitignore에 추가 (이미 있을 수도 있음)
echo ".eas-env/" >> .gitignore
```

### 예시 시나리오

**시나리오 1: 회사 계정과 개인 계정 분리**

```bash
# 회사 프로젝트용
source scripts/ios/eas-login-helper.sh company
eas login  # 회사 계정으로 로그인
# ... 작업 ...
deactivate_eas_env

# 개인 프로젝트용 (기존 환경 사용)
eas whoami  # 원래 계정
```

**시나리오 2: 프로덕션과 스테이징 환경 분리**

```bash
# 프로덕션 환경
./scripts/ios/eas-env.sh production build --platform ios --profile production

# 스테이징 환경
./scripts/ios/eas-env.sh staging build --platform ios --profile staging
```

### 주의사항

- 독립 환경을 사용하는 동안에는 해당 환경의 인증 정보만 사용됩니다
- `deactivate_eas_env`를 실행하거나 쉘을 종료하면 원본 환경으로 자동 복원됩니다
- 각 환경은 완전히 독립적이므로, 각 환경에서 별도로 로그인해야 합니다

## 라이선스

이 스크립트는 프로젝트와 동일한 라이선스를 따릅니다.

## 기여

버그 리포트나 개선 제안은 이슈로 등록해주세요.

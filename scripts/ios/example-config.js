/**
 * iOS 빌드 설정 파일 예제
 * 
 * 이 파일을 scripts/ios/config.js로 복사하여 사용하거나,
 * 프로젝트 루트의 app.json에 다음 설정을 포함시키세요.
 */

module.exports = {
  expo: {
    // 앱 이름 (필수)
    name: "MyApp",
    
    // 앱 버전 (필수, Semantic Versioning 형식)
    version: "1.0.0",
    
    // iOS 관련 설정
    ios: {
      // Bundle Identifier (필수)
      // Apple Developer Portal에서 등록한 App ID와 일치해야 함
      bundleIdentifier: "com.example.myapp",
      
      // Apple Team ID (필수)
      // Apple Developer Portal > Membership에서 확인 가능
      // https://developer.apple.com/account/#/membership/
      appleTeamId: "ABCD123456",
      
      // Build Number (선택, 자동 증가됨)
      // 빌드할 때마다 자동으로 1씩 증가합니다
      buildNumber: "1",
      
      // Scheme (선택, 기본값: name과 동일)
      // Xcode 프로젝트의 Scheme 이름
      scheme: "MyApp",
      
      // 기타 iOS 설정
      supportsTablet: true,
      
      // Info.plist 추가 설정 (선택)
      infoPlist: {
        // 예: Push Notifications 권한 메시지
        NSUserNotificationsUsageDescription: "알림을 보내기 위해 권한이 필요합니다.",
      },
    },
    
    // 프로젝트 기본 설정
    scheme: "myapp", // Deep linking용 scheme
    slug: "myapp",
  },
};

/**
 * app.json 사용 예제
 * 
 * 프로젝트 루트의 app.json 파일에 다음 내용을 포함:
 * 
 * {
 *   "expo": {
 *     "name": "MyApp",
 *     "version": "1.0.0",
 *     "ios": {
 *       "bundleIdentifier": "com.example.myapp",
 *       "appleTeamId": "ABCD123456",
 *       "buildNumber": "1",
 *       "scheme": "MyApp"
 *     }
 *   }
 * }
 */

/**
 * 환경 변수 사용 예제
 * 
 * config.js에서 .env 파일을 읽어 사용할 수도 있습니다:
 * 
 * const path = require('path');
 * const fs = require('fs');
 * 
 * // .env 파일 읽기
 * const env = {};
 * const envPath = path.join(__dirname, '../../../.env');
 * if (fs.existsSync(envPath)) {
 *   fs.readFileSync(envPath, 'utf8')
 *     .split('\n')
 *     .forEach(line => {
 *       const [key, value] = line.split('=');
 *       if (key && value) env[key.trim()] = value.trim();
 *     });
 * }
 * 
 * module.exports = {
 *   expo: {
 *     name: process.env.APP_NAME || "MyApp",
 *     version: process.env.APP_VERSION || "1.0.0",
 *     ios: {
 *       bundleIdentifier: process.env.IOS_BUNDLE_ID || "com.example.myapp",
 *       appleTeamId: process.env.APPLE_TEAM_ID || "",
 *       buildNumber: process.env.IOS_BUILD_NUMBER || "1",
 *     },
 *   },
 * };
 */

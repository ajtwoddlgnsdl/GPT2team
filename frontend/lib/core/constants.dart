import 'dart:io';
import 'package:flutter/foundation.dart'; // kIsWeb 사용을 위해 추가
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 💡 dotenv 패키지 임포트

class ApiConstants {
  static String get baseUrl {
    // 💡 웹 브라우저에서 실행될 경우의 방어 로직
    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    }
    // 💡 안드로이드 기기(에뮬레이터 포함)일 경우
    if (Platform.isAndroid) {
      return 'http://10.30.80.211:8000';
    }
    // 💡 iOS 시뮬레이터 및 윈도우/맥 데스크탑일 경우
    return 'http://127.0.0.1:8000';
  }

  // 💡 .env 파일에서 JWT 시크릿 키를 불러오도록 수정합니다.
  static String get jwtSecretKey =>
      dotenv.env['JWT_SECRET_KEY'] ?? 'fallback_secret_key';
}

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 1. 보안 금고 프로바이더 (어디서든 금고에 접근 가능하게 해줌)
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

// 2. Dio 통신 프로바이더 (우리의 문지기)
final dioProvider = Provider<Dio>((ref) {
  final storage = ref.watch(secureStorageProvider);
  
  // 서버 주소 세팅 (일단 안드로이드 에뮬레이터 로컬 주소 기준, iOS는 127.0.0.1)
  final dio = Dio(BaseOptions(
    baseUrl: 'http://10.0.2.2:8000', // 로컬 테스트용
    connectTimeout: const Duration(seconds: 5),
  ));

  // 💡 인터셉터 (통신을 가로채서 조작함!)
  dio.interceptors.add(
    InterceptorsWrapper(
      // [요청을 보내기 직전]
      onRequest: (options, handler) async {
        // 금고에서 토큰을 꺼냄
        final accessToken = await storage.read(key: 'access_token');
        
        // 토큰이 있으면 헤더에 Authorization을 달아줌
        if (accessToken != null) {
          options.headers['Authorization'] = 'Bearer $accessToken';
        }
        return handler.next(options); // 이제 가던 길 가라!
      },
      
      // [에러가 났을 때]
      onError: (DioException e, handler) async {
        // 만약 401 (토큰 만료/권한 없음) 에러라면?
        if (e.response?.statusCode == 401) {
          // TODO: 여기에 몰래 '/login' API를 다시 쏴서 새 토큰을 받아오는 로직을 짤 거야!
          print("🚨 토큰 만료됨! 재인증 로직 가동 필요!");
        }
        return handler.next(e);
      },
    ),
  );

  return dio;
});
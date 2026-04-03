import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'screens/login_screen.dart'; // 나중에 만들 화면

void main() {
  runApp(
    // 💡 Riverpod을 쓰기 위한 필수 장착 템플릿!
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VN Game',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      // 일단 임시로 빈 화면 띄워두기
      home: const Scaffold(
        body: Center(child: Text('플러터 세팅 완료! 🚀')),
      ),
    );
  }
}
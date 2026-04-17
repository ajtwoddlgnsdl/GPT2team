import 'package:flutter/material.dart';
import 'screens/auth/title_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // --dart-define=RESET=true 로 실행하면 저장된 로그인 정보를 초기화
  const bool reset = bool.fromEnvironment('RESET', defaultValue: false);
  if (reset) {
    await const FlutterSecureStorage().deleteAll();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Project Heroine',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        primarySwatch: Colors.blue,
      ),
      home: const TitleScreen(),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../core/api_client.dart';
import '../story/story_screen.dart';
import '../lobby/lobby_screen.dart';

class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key});

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

enum TitleState { loading, needGuestLogin, readyToStart }

class _TitleScreenState extends State<TitleScreen> {
  TitleState _state = TitleState.loading;

  final TextEditingController _adminKeyCtrl = TextEditingController(
    text: "여기에_어드민키_입력",
  );
  final TextEditingController _offlineDaysCtrl = TextEditingController(
    text: "1",
  );
  final TextEditingController _cheatHourCtrl = TextEditingController(
    text: "14",
  );

  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
  }

  // 💡 자동 로그인 로직
  Future<void> _checkAutoLogin() async {
    final userId = await ApiClient().storage.read(key: 'user_id');
    final token = await ApiClient().storage.read(key: 'access_token');

    if (userId != null && token != null) {
      debugPrint("✅ 기존 유저 확인! 백그라운드 로그인 진행 중...");
      try {
        // 유저 ID를 이용해 백엔드의 /login API로 상태와 토큰 갱신
        final response = await ApiClient().dio.post(
          '/login',
          queryParameters: {'user_id': userId},
        );
        if (response.statusCode == 200 &&
            response.data['status'] == 'success') {
          final newToken = response.data['access_token'];
          await ApiClient().storage.write(key: 'access_token', value: newToken);
          if (mounted) {
            setState(
              () => _state = TitleState.readyToStart,
            ); // Touch to start 상태로 변경
          }
          return;
        }
      } catch (e) {
        debugPrint("🚨 자동 로그인 실패. 게스트 로그인으로 전환: $e");
      }
    } else {
      debugPrint("❌ 저장된 유저 없음. 게스트 로그인 버튼 표시.");
    }

    if (mounted) {
      setState(() => _state = TitleState.needGuestLogin);
    }
  }

  Future<void> _guestLogin() async {
    setState(() => _state = TitleState.loading);
    try {
      final response = await ApiClient().dio.post('/auth/guest-login');
      if (response.statusCode == 200) {
        final token = response.data['access_token'];
        final userId = response.data['user_id'];
        await ApiClient().storage.write(key: 'access_token', value: token);
        await ApiClient().storage.write(
          key: 'user_id',
          value: userId,
        ); // 다음 로그인을 위해 user_id도 저장
        debugPrint("✅ 게스트 로그인 성공, 토큰 및 유저 ID 저장 완료!");

        // 게스트 로그인은 터치 대기 없이 바로 스토리 체크로 넘어갑니다.
        _checkStoryStatus();
      }
    } on DioException catch (e) {
      debugPrint("🚨 게스트 로그인 실패: ${e.response?.data ?? e.message}");
      if (mounted) {
        setState(() => _state = TitleState.needGuestLogin);
      }
    }
  }

  Future<void> _checkStoryStatus() async {
    try {
      final response = await ApiClient().dio.get('/check-story');
      if (response.statusCode == 200) {
        final data = response.data;
        if (!mounted) return;

        if (data['auto_play_story']['is_available'] == true) {
          final autoPlay = data['auto_play_story'];
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => StoryScreen(
                storyId: autoPlay['story_id'],
                storyTicket: autoPlay['story_ticket'],
                heroineName: autoPlay['heroine_name'],
              ),
            ),
          );
        } else {
          // 볼 스토리가 없으면 바로 로비로!
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LobbyScreen()),
          );
        }
      }
    } on DioException catch (e) {
      debugPrint("🚨 스토리 체크 실패: ${e.response?.data ?? e.message}");
      if (mounted) {
        setState(() => _state = TitleState.needGuestLogin);
      }
    }
  }

  // 💡 개발자 전용 디버그 패널
  void _showAdminPanel() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            '🛠️ 개발자 디버그 패널',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _adminKeyCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Admin Key',
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                ),
                TextField(
                  controller: _offlineDaysCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: '오프라인 일수 조작',
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                ),
                TextField(
                  controller: _cheatHourCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: '시간 조작 (0~23)',
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                // 1. 버튼을 누르자마자 텍스트 값들을 저장하고 다이얼로그를 즉시 닫습니다.
                final adminKey = _adminKeyCtrl.text;
                final offlineDaysText = _offlineDaysCtrl.text;
                final cheatHourText = _cheatHourCtrl.text;

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }

                // 2. 통신하는 동안 타이틀 화면에 로딩 인디케이터를 띄워줍니다.
                setState(() => _state = TitleState.loading);

                try {
                  final userId = await ApiClient().storage.read(key: 'user_id');
                  if (userId == null) {
                    throw Exception("유저 ID가 없습니다. 게스트 로그인을 먼저 1회 진행해주세요.");
                  }

                  int offlineDays = int.tryParse(offlineDaysText) ?? 0;
                  int cheatHour = int.tryParse(cheatHourText) ?? 14;

                  // 1. 오프라인 일수 적용 (0이면 날짜 변경 없이 로그인만 처리됨)
                  final loginRes = await ApiClient().dio.post(
                    '/admin/login',
                    queryParameters: {
                      'user_id': userId,
                      'cheat_offline_days': offlineDays,
                    },
                    options: Options(headers: {'admin-key': adminKey}),
                  );

                  // 💡 백엔드가 200 OK를 주더라도 내부 논리 에러(status: error)일 경우를 명시적으로 던집니다!
                  if (loginRes.data['status'] != 'success') {
                    throw Exception(
                      loginRes.data['error_code'] ?? '어드민 권한이 없거나 로그인에 실패했습니다.',
                    );
                  }

                  await ApiClient().storage.write(
                    key: 'access_token',
                    value: loginRes.data['access_token'],
                  );
                  debugPrint("✅ 치트 로그인 완료! (오프라인 $offlineDays일 적용)");

                  // 2. 지정된 시간으로 스토리 체크 후 다이렉트 진입
                  final storyRes = await ApiClient().dio.get(
                    '/admin/check-story',
                    queryParameters: {'cheat_hour': cheatHour},
                    options: Options(headers: {'admin-key': adminKey}),
                  );

                  if (storyRes.data['status'] != 'success') {
                    throw Exception(
                      storyRes.data['error_code'] ?? '스토리 체크에 실패했습니다.',
                    );
                  }

                  final autoPlay = storyRes.data['auto_play_story'];

                  if (!mounted) return; // 기존 화면(TitleScreen)이 떠있는지 확인

                  if (autoPlay['is_available'] == true) {
                    Navigator.pushReplacement(
                      context, // 안전하게 기존 TitleScreen의 context를 사용!
                      MaterialPageRoute(
                        builder: (context) => StoryScreen(
                          storyId: autoPlay['story_id'],
                          storyTicket: autoPlay['story_ticket'],
                          heroineName: autoPlay['heroine_name'],
                        ),
                      ),
                    );
                  } else {
                    debugPrint("❌ 조작한 시간대에 볼 스토리가 없습니다. 로비로 이동합니다.");
                    Navigator.pushReplacement(
                      context, // 여기도 기존 context를 사용!
                      MaterialPageRoute(
                        builder: (context) => const LobbyScreen(),
                      ),
                    );
                  }
                } catch (e) {
                  // 💡 DioException 외에 위에서 수동으로 던진 Exception도 모두 잡도록 수정
                  debugPrint("🚨 치트 적용 에러: $e");
                  if (mounted) {
                    setState(
                      () => _state = TitleState.readyToStart,
                    ); // 에러 시 로딩 해제
                    String errorMsg = e.toString().replaceAll(
                      'Exception: ',
                      '',
                    );
                    if (e is DioException) {
                      errorMsg = e.response?.data?['error_code'] ?? '서버 통신 오류';
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('치트 적용 실패: $errorMsg'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                }
              },
              child: const Text(
                '치트 적용 및 시작',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('닫기', style: TextStyle(color: Colors.grey)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            // Touch to start 상태일 때만 화면 터치 시 스토리 체크 로직 실행
            onTap: _state == TitleState.readyToStart ? _checkStoryStatus : null,
            child: Center(
              child: _state == TitleState.loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Game Title',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 50),
                        if (_state == TitleState.needGuestLogin)
                          ElevatedButton(
                            onPressed: _guestLogin,
                            child: const Text('게스트로 시작하기'),
                          )
                        else if (_state == TitleState.readyToStart)
                          const Text(
                            'Touch to Start',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
            ),
          ),
          // 💡 개발자 전용 디버그 버튼 (우측 상단)
          Positioned(
            top: 50,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.bug_report, color: Colors.grey, size: 30),
              onPressed: _showAdminPanel,
            ),
          ),
        ],
      ),
    );
  }
}

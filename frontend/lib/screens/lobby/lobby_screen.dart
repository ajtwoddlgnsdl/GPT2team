import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../story/story_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  String _playerName = "주인공";
  int _ap = 0;
  int _money = 0;
  int _serverHour = 12; // 서버에서 받아올 시간 (기본값: 낮)
  int _serverDay = 1; // 서버 기준 날짜 (자정 체크용)
  bool _isLoading = true;

  Duration _timeOffset = Duration.zero; // 기기 시간과 서버 시간의 차이
  Timer? _timeSyncTimer;

  @override
  void initState() {
    super.initState();
    _loadLobbyData();
  }

  Future<void> _loadLobbyData() async {
    try {
      final name = await ApiClient().storage.read(key: 'username');
      if (name != null) _playerName = name;

      // 1. 서버 시간 가져오기
      final requestTime = DateTime.now(); // 💡 API 요청 시작 시간 기록
      final timeResponse = await ApiClient().dio.get('/server-time');
      final responseTime = DateTime.now(); // 💡 API 응답 도착 시간 기록

      if (timeResponse.statusCode == 200) {
        final serverTime = DateTime.parse(timeResponse.data['timestamp']);

        final latency =
            responseTime.difference(requestTime) ~/ 2; // 통신 지연시간(왕복의 절반) 계산
        final adjustedServerTime = serverTime.add(latency); // 서버 시간에 지연시간 보정!

        _timeOffset = adjustedServerTime.difference(
          DateTime.now(),
        ); // 훨씬 정밀해진 오프셋 저장
        _serverHour = adjustedServerTime.hour;
        _serverDay = adjustedServerTime.day;

        _startTimeMonitor(); // 타이머 시작
      }

      // 2. 유저 상태 가져오기
      final response = await ApiClient().dio.get('/user/status');
      if (response.statusCode == 200) {
        setState(() {
          if (response.data['username'] != null) {
            _playerName = response.data['username'];
          }
          _ap = response.data['ap'];
          _money = response.data['money'];
        });
      }
    } catch (e) {
      debugPrint("🚨 유저 상태창 에러: $e");
      setState(() {
        _ap = 50;
        _money = 1500;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 💡 백그라운드에서도 멈추지 않는 Time Offset 방식의 시간 모니터링
  void _startTimeMonitor() {
    _timeSyncTimer?.cancel();

    void checkTime() {
      // 기기의 현재 시간에 아까 구해둔 오프셋을 더해서 지금 서버 시간을 유추!
      final estimatedServerTime = DateTime.now().add(_timeOffset);

      // 현재 저장된 시간대와 유추한 시간의 시간대가 달라졌거나, 날짜가 넘어갔다면 이벤트 발동
      if (_getZoneCode(estimatedServerTime.hour) != _getZoneCode(_serverHour) ||
          estimatedServerTime.day != _serverDay) {
        _handleTimeBoundaryCrossed(estimatedServerTime);
      }
    }

    // 💡 타이머 대기 없이 접속 직후 즉시 1회 체크!
    checkTime();

    _timeSyncTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      checkTime();
    });
  }

  // 시간대 판별 (새벽:0, 아침:1, 낮:2, 밤:3)
  int _getZoneCode(int hour) {
    if (hour >= 6 && hour < 12) return 1;
    if (hour >= 12 && hour < 18) return 2;
    if (hour >= 18 && hour < 24) return 3;
    return 0;
  }

  Future<void> _handleTimeBoundaryCrossed(DateTime newEstimatedTime) async {
    _timeSyncTimer?.cancel(); // 중복 방지

    try {
      // 1. 서버에 더블 체크
      final verifyRes = await ApiClient().dio.post(
        '/verify-time',
        data: {"client_estimated_hour": newEstimatedTime.hour},
      );

      if (verifyRes.statusCode == 200 &&
          verifyRes.data['status'] == 'success') {
        debugPrint("✅ 시간 동기화 성공! 새로운 시간대로 갱신합니다.");

        // 2. 밤 -> 새벽(자정)이 지났다면 /login API로 상태 갱신
        if (newEstimatedTime.day != _serverDay) {
          final userId = await ApiClient().storage.read(key: 'user_id');
          if (userId != null) {
            await ApiClient().dio.post(
              '/login',
              queryParameters: {'user_id': userId},
            );

            // 일일 초기화가 되었으니 유저 상태(AP, Money) 다시 불러오기
            final userRes = await ApiClient().dio.get('/user/status');
            if (userRes.statusCode == 200 && mounted) {
              setState(() {
                _ap = userRes.data['ap'];
                _money = userRes.data['money'];
              });
            }
          }
        }

        // 3. 갱신된 시간대에 볼 스토리가 있는지 체크
        final storyRes = await ApiClient().dio.get('/check-story');
        if (storyRes.statusCode == 200 &&
            storyRes.data['auto_play_story']['is_available'] == true) {
          final autoPlay = storyRes.data['auto_play_story'];
          if (!mounted) return;
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
          // 볼 스토리가 없으면 로비의 시간대와 날짜만 업데이트
          if (mounted) {
            setState(() {
              _serverHour = newEstimatedTime.hour;
              _serverDay = newEstimatedTime.day;
            });
            _startTimeMonitor(); // 다시 타이머 재개
          }
        }
      } else {
        // 실패 시 전체 데이터를 다시 불러와서 시간/오프셋 강제 재보정
        _loadLobbyData();
      }
    } catch (e) {
      debugPrint("🚨 시간 경계 처리 에러: $e");
      _startTimeMonitor(); // 에러 발생 시 일단 타이머 재개
    }
  }

  String _getBackgroundImage() {
    final int hour = _serverHour;
    if (hour >= 6 && hour < 12) return 'assets/images/bg/lobby_morning.jpg';
    if (hour >= 12 && hour < 18) return 'assets/images/bg/lobby_afternoon.jpg';
    if (hour >= 18 && hour < 24) return 'assets/images/bg/lobby_night.jpg';
    return 'assets/images/bg/lobby_dawn.jpg';
  }

  // 💡 시간대별 동적 버튼 생성
  Widget _buildDynamicButtons() {
    final int hour = _serverHour;
    List<Widget> buttons = [];

    if (hour >= 6 && hour < 12) {
      // 아침: 핸드폰
      buttons.add(
        _buildActionButton(Icons.smartphone, "핸드폰", Colors.blueAccent),
      );
    } else if (hour >= 12 && hour < 18) {
      // 낮: 미니게임 + 핸드폰
      buttons.add(
        _buildActionButton(Icons.videogame_asset, "미니게임", Colors.green),
      );
      buttons.add(
        _buildActionButton(Icons.smartphone, "핸드폰", Colors.blueAccent),
      );
    } else if (hour >= 18 && hour < 24) {
      // 밤: 핸드폰
      buttons.add(
        _buildActionButton(Icons.smartphone, "핸드폰", Colors.blueAccent),
      );
    } else {
      // 새벽: 현재는 버튼 없음 (추후 기능 확장을 위해 SizedBox.shrink()로 반환)
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: buttons,
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.8),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: color.withValues(alpha: 0.5)),
        ),
      ),
      onPressed: () {
        debugPrint("$label 버튼 클릭됨!");
      },
      icon: Icon(icon),
      label: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
  }

  @override
  void dispose() {
    _timeSyncTimer?.cancel(); // 메모리 누수 방지
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // 1. 🌅 시간대별 배경
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(_getBackgroundImage()),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // 2. 💰 상단 상태창
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _playerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.bolt,
                        color: Colors.yellowAccent,
                        size: 20,
                      ),
                      Text(
                        " $_ap",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 15),
                      const Icon(
                        Icons.monetization_on,
                        color: Colors.amber,
                        size: 20,
                      ),
                      Text(
                        " $_money",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 3. 🎯 메인 행동 버튼 (시간대에 맞춰 렌더링!)
          Positioned(
            bottom: 50,
            left: 20,
            right: 20,
            child: _buildDynamicButtons(),
          ),
        ],
      ),
    );
  }
}

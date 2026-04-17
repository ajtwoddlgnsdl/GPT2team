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
  String _playerName = '주인공';
  int _ap = 0;
  int _money = 0;
  int _serverHour = 12;
  int _serverDay = 1;
  bool _isLoading = true;

  Duration _timeOffset = Duration.zero;
  Timer? _timeSyncTimer;

  @override
  void initState() {
    super.initState();
    _loadLobbyData();
  }

  Future<void> _loadLobbyData() async {
    try {
      final name = await ApiClient().storage.read(key: 'username');
      if (name != null) {
        _playerName = name;
      }

      final requestTime = DateTime.now();
      final timeResponse = await ApiClient().dio.get('/server-time');
      final responseTime = DateTime.now();

      if (timeResponse.statusCode == 200) {
        final rawTimestamp = timeResponse.data['timestamp'].toString().split(
          '+',
        )[0];
        final serverTime = DateTime.parse(rawTimestamp);
        final latency = responseTime.difference(requestTime) ~/ 2;
        final adjustedServerTime = serverTime.add(latency);

        _timeOffset = adjustedServerTime.difference(DateTime.now());
        _serverHour = adjustedServerTime.hour;
        _serverDay = adjustedServerTime.day;

        _startTimeMonitor();
      }

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
      debugPrint('로비 데이터 로드 실패: $e');
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

  void _startTimeMonitor() {
    _timeSyncTimer?.cancel();

    void checkTime() {
      final estimatedServerTime = DateTime.now().add(_timeOffset);

      if (_getZoneCode(estimatedServerTime.hour) != _getZoneCode(_serverHour) ||
          estimatedServerTime.day != _serverDay) {
        _handleTimeBoundaryCrossed(estimatedServerTime);
      }
    }

    checkTime();

    _timeSyncTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      checkTime();
    });
  }

  int _getZoneCode(int hour) {
    if (hour >= 6 && hour < 12) return 1;
    if (hour >= 12 && hour < 18) return 2;
    if (hour >= 18 && hour < 24) return 3;
    return 0;
  }

  Future<void> _handleTimeBoundaryCrossed(DateTime newEstimatedTime) async {
    _timeSyncTimer?.cancel();

    try {
      final verifyRes = await ApiClient().dio.post(
        '/verify-time',
        data: {'client_estimated_hour': newEstimatedTime.hour},
      );

      if (verifyRes.statusCode == 200 &&
          verifyRes.data['status'] == 'success') {
        if (newEstimatedTime.day != _serverDay) {
          final userId = await ApiClient().storage.read(key: 'user_id');
          if (userId != null) {
            await ApiClient().dio.post(
              '/login',
              queryParameters: {'user_id': userId},
            );

            final userRes = await ApiClient().dio.get('/user/status');
            if (userRes.statusCode == 200 && mounted) {
              setState(() {
                _ap = userRes.data['ap'];
                _money = userRes.data['money'];
              });
            }
          }
        }

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
          if (mounted) {
            setState(() {
              _serverHour = newEstimatedTime.hour;
              _serverDay = newEstimatedTime.day;
            });
            _startTimeMonitor();
          }
        }
      } else {
        _loadLobbyData();
      }
    } catch (e) {
      debugPrint('시간 경계 처리 실패: $e');
      _startTimeMonitor();
    }
  }

  String _getBackgroundImage() {
    final int hour = _serverHour;
    if (hour >= 6 && hour < 12) return 'assets/images/bg/lobby_morning.jpg';
    if (hour >= 12 && hour < 18) return 'assets/images/bg/lobby_afternoon.jpg';
    if (hour >= 18 && hour < 24) return 'assets/images/bg/lobby_night.jpg';
    return 'assets/images/bg/lobby_dawn.jpg';
  }

  bool _isRoomPeriod() {
    return (_serverHour >= 6 && _serverHour < 12) ||
        (_serverHour >= 18 && _serverHour < 24);
  }

  LinearGradient _getWindowGradient() {
    final int hour = _serverHour;
    if (hour >= 6 && hour < 12) {
      return const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFF9DFA7), Color(0xFFF7B8A6), Color(0xFFD9ECFF)],
      );
    }
    if (hour >= 18 && hour < 24) {
      return const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF17203C), Color(0xFF3D3A74), Color(0xFF6F5D93)],
      );
    }
    if (hour >= 12 && hour < 18) {
      return const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF9ED8FF), Color(0xFFCBEAFF), Color(0xFFF8FBFF)],
      );
    }
    return const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF30405E), Color(0xFF6A7FA2), Color(0xFFDDE7F5)],
    );
  }

  List<BoxShadow> _getWindowGlow() {
    if (_serverHour >= 18 && _serverHour < 24) {
      return const [
        BoxShadow(
          color: Color(0x664A6EFF),
          blurRadius: 36,
          spreadRadius: 6,
        ),
      ];
    }

    return const [
      BoxShadow(
        color: Color(0x55FFD9A6),
        blurRadius: 28,
        spreadRadius: 4,
      ),
    ];
  }

  Widget _buildDynamicButtons() {
    final int hour = _serverHour;
    final List<Widget> buttons = [];

    if (hour >= 6 && hour < 12) {
      buttons.add(
        _buildActionButton(Icons.smartphone, '핸드폰 열기', Colors.blueAccent),
      );
    } else if (hour >= 12 && hour < 18) {
      buttons.add(
        _buildActionButton(Icons.videogame_asset, '미니게임', Colors.green),
      );
      buttons.add(
        _buildActionButton(Icons.smartphone, '핸드폰 열기', Colors.blueAccent),
      );
    } else if (hour >= 18 && hour < 24) {
      buttons.add(
        _buildActionButton(Icons.smartphone, '핸드폰 열기', Colors.blueAccent),
      );
    } else {
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
        debugPrint('$label 버튼 클릭');
      },
      icon: Icon(icon),
      label: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
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
              const Icon(Icons.bolt, color: Colors.yellowAccent, size: 20),
              Text(
                ' $_ap',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(width: 15),
              const Icon(
                Icons.monetization_on,
                color: Colors.amber,
                size: 20,
              ),
              Text(
                ' $_money',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoomScreen() {
    final bool isNight = _serverHour >= 18 && _serverHour < 24;

    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFEEE5D9), Color(0xFFD6C2AE)],
            ),
          ),
        ),
        Positioned.fill(
          child: Column(
            children: [
              Expanded(
                flex: 5,
                child: Container(
                  color: isNight
                      ? const Color(0xFF3F3448)
                      : const Color(0xFFEADFD2),
                ),
              ),
              Expanded(
                flex: 2,
                child: Container(color: const Color(0xFF8A644A)),
              ),
            ],
          ),
        ),
        Positioned(
          left: 28,
          right: 28,
          top: 120,
          child: Container(
            height: 210,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF5F432E),
              borderRadius: BorderRadius.circular(18),
              boxShadow: _getWindowGlow(),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: _getWindowGradient(),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Stack(
                children: [
                  if (!isNight)
                    Positioned(
                      right: 26,
                      top: 22,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFFFE4A3),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x77FFD57A),
                              blurRadius: 16,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (isNight)
                    Positioned(
                      right: 24,
                      top: 20,
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFF2F0D8),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x668C91FF),
                              blurRadius: 18,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 26,
                    child: Container(
                      height: 58,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 185,
          child: Container(
            height: 125,
            decoration: BoxDecoration(
              color: const Color(0xFFE2B7A1),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 14,
                  offset: Offset(0, 8),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 16,
          bottom: 120,
          child: Container(
            width: 120,
            height: 82,
            decoration: BoxDecoration(
              color: const Color(0xFFC68F63),
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        Positioned(
          left: 30,
          bottom: 160,
          child: Container(
            width: 88,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFF6E6D6),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        Positioned(
          right: 18,
          bottom: 116,
          child: Container(
            width: 145,
            height: 105,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFB77E57),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: 70,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5E8D5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2337),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            height: 52,
            color: const Color(0xFF6E4F3D),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 40,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Text(
                  isNight
                      ? '밤은 조용하다. 오늘의 여운이 방 안에 남아 있다.'
                      : '아침 공기가 방 안으로 스며든다. 오늘의 시작은 여기서부터.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildActionButton(
                Icons.smartphone,
                '핸드폰 열기',
                Colors.lightBlueAccent,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _timeSyncTimer?.cancel();
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
          if (_isRoomPeriod())
            _buildRoomScreen()
          else
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
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: _buildStatusBar(),
          ),
          if (!_isRoomPeriod())
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

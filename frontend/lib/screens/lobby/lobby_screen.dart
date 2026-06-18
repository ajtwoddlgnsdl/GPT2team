import 'dart:ui';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/api_client.dart';
import '../story/story_screen.dart';
import 'phone_screen.dart';
import 'minigame_screen.dart';
import 'cafe_game_screen.dart';
import 'album_constants.dart';
import 'album_home_screen.dart';
import 'calendar_home_screen.dart';
import '../chat/chat_list_screen.dart';
import '../chat/chat_room_screen.dart';
import 'gift_app_screen.dart';


/// 다각형 기반 핸드폰 히트박스 (원근감 있는 기울어진 스마트폰 모양 매칭)
class PhoneHitbox {
  /// 화면 좌표계 기준 다각형 꼭짓점 (좌상 → 우상 → 우하 → 좌하, 시계방향)
  final List<Offset> polygon;

  /// 모서리 둥글기 반경
  final double cornerRadius;

  /// 배경 조명에 어울리는 글로우 색상
  final Color glowColor;

  const PhoneHitbox({
    required this.polygon,
    this.cornerRadius = 6.0,
    this.glowColor = const Color(0xFFFFFFFF),
  });

  bool get isEmpty => polygon.length < 3;

  Rect get boundingBox {
    if (isEmpty) return Rect.zero;
    double minX = polygon[0].dx, minY = polygon[0].dy;
    double maxX = polygon[0].dx, maxY = polygon[0].dy;
    for (final p in polygon) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }
}

class LobbyScreen extends StatefulWidget {
  final String? unlockedIllustrationId;
  const LobbyScreen({super.key, this.unlockedIllustrationId});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen>
    with TickerProviderStateMixin {
  String _playerName = "주인공";
  int _ap = 0;
  int _studyAp = 0;
  int _money = 0;
  int _serverHour = 12; // 서버에서 받아올 시간 (기본값: 낮)
  int _serverDay = 1; // 서버 기준 날짜 (자정 체크용)
  bool _isLoading = true;

  Duration _timeOffset = Duration.zero; // 기기 시간과 서버 시간의 차이
  Timer? _timeSyncTimer;

  // 📱 스마트폰 UI 상태
  bool _isPhoneOpen = false;

  // 💡 핸드폰 히트박스 펄스 애니메이션
  late final AnimationController _pulseCtrl;

  // 📱 핸드폰 통합 애니메이션 (올라오기 + 확장)
  late final AnimationController _phoneAnimCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _phoneAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _loadLobbyData();

    // 💡 스토리 감상 후 넘어온 일러스트 해금 정보가 있다면 오버레이 팝업 트리거
    if (widget.unlockedIllustrationId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showIllustrationUnlockOverlay(context, widget.unlockedIllustrationId!);
      });
    }
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
        // 💡 서버가 준 문자열(예: ...T18:23:56+09:00)에서 타임존(+09:00) 꼬리표만 잘라냄
        final rawTimestamp = timeResponse.data['timestamp'].toString().split(
          '+',
        )[0];
        final serverTime = DateTime.parse(
          rawTimestamp,
        ); // 꼬리표가 없으므로 무조건 18시 그대로 파싱됨!

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
          _studyAp = response.data['study_ap'] ?? 0;
          _money = response.data['money'];
        });
      }
    } catch (e) {
      debugPrint("🚨 유저 상태창 에러: $e");
      setState(() {
        _ap = 50;
        _studyAp = 50;
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

    // 📱 시간대가 바뀌면 스마트폰 닫기
    if (_isPhoneOpen) {
      setState(() => _isPhoneOpen = false);
    }

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
                _studyAp = userRes.data['study_ap'] ?? 0;
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

  // 📱 배경에 핸드폰 히트박스가 있는 시간대인지 (방 일러스트)
  bool _hasPhoneInBackground() {
    final zone = _getZoneCode(_serverHour);
    // 새벽(0)만 제외, 아침(1)/낮(2)/밤(3)은 방 일러스트에 핸드폰 있음
    return zone != 0;
  }

  // 📱 시간대별 핸드폰 히트박스 다각형 (배경 이미지 속 스마트폰 모양에 정확히 매칭)
  // 원본 이미지(1080x1920) 기준 꼭짓점 좌표를 정의한 뒤
  // BoxFit.cover 보정을 거쳐 실제 화면 좌표로 변환
  PhoneHitbox _getPhoneHitbox(double sw, double sh) {
    const double imageW = 1080;
    const double imageH = 1920;
    const double imageAspect = imageW / imageH;
    final double screenAspect = sw / sh;

    double scaledW, scaledH, offX = 0, offY = 0;
    if (screenAspect > imageAspect) {
      scaledW = sw;
      scaledH = sw / imageAspect;
      offY = (sh - scaledH) / 2;
    } else {
      scaledH = sh;
      scaledW = sh * imageAspect;
      offX = (sw - scaledW) / 2;
    }

    Offset toScreen(double imgX, double imgY) {
      return Offset(
        offX + (imgX / imageW) * scaledW,
        offY + (imgY / imageH) * scaledH,
      );
    }

    final zone = _getZoneCode(_serverHour);
    List<Offset> poly;
    double cornerRadius;

    Color glowColor;

    switch (zone) {
      case 1: // 아침 - 책상 위 스탠드 왼쪽
        poly = [
          toScreen(301, 1177),
          toScreen(357, 1180),
          toScreen(347, 1280),
          toScreen(285, 1280),
        ];
        cornerRadius = 5.0;
        glowColor = const Color(0xFFFFF3D4); // 아침 따스한 햇살
        break;
      case 3: // 밤 - 책상 위 (스탠드 불빛)
        poly = [
          toScreen(301, 1177),
          toScreen(357, 1180),
          toScreen(347, 1280),
          toScreen(285, 1280),
        ];
        cornerRadius = 5.0;
        glowColor = const Color(0xFFFFE4A0); // 밤 스탠드 불빛 웜톤
        break;
      case 2: // 낮 (카페) - 카운터 위 핸드폰
        poly = [
          toScreen(543, 1456),
          toScreen(635, 1460),
          toScreen(614, 1589),
          toScreen(505, 1580),
        ];
        cornerRadius = 8.0;
        glowColor = const Color(0xFFFFF0D0); // 카페 따뜻한 자연광
        break;
      default:
        return const PhoneHitbox(polygon: []);
    }

    return PhoneHitbox(
      polygon: poly,
      cornerRadius: cornerRadius,
      glowColor: glowColor,
    );
  }

  // 📱 통합 핸드폰 애니메이션 실행
  void _openPhone() {
    setState(() => _isPhoneOpen = true);
    _phoneAnimCtrl.forward(from: 0.0);
  }

  void _closePhone() {
    _phoneAnimCtrl.reverse().then((_) {
      if (mounted) setState(() => _isPhoneOpen = false);
    });
  }

  // 💡 시간대별 동적 버튼 생성 (핸드폰 버튼은 히트박스/FAB로 대체됨)
  Widget _buildDynamicButtons() {
    final int hour = _serverHour;
    List<Widget> buttons = [];

    if (hour >= 6 && hour < 12) {
      // 아침: 핸드폰만 있었으므로 히트박스로 대체 → 추가 버튼 없음
    } else if (hour >= 12 && hour < 18) {
      // 낮: 미니게임 (핸드폰은 FAB로 분리)
      buttons.add(
        _buildActionButton(
          Icons.videogame_asset,
          "미니게임",
          Colors.green,
          onPressed: _openCafeGame,
        ),
      );
    } else if (hour >= 18 && hour < 24) {
      // 밤: 핸드폰만 있었으므로 히트박스로 대체 → 추가 버튼 없음
    } else {
      // 새벽: 현재는 버튼 없음 (추후 기능 확장을 위해 SizedBox.shrink()로 반환)
      return const SizedBox.shrink();
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: buttons,
    );
  }

  void _openCafeGame() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CafeGameScreen(
          actionPoints: _ap,
          money: _money,
          day: _serverDay,
          onClose: () => Navigator.of(context).pop(),
          onRewardEarned: (earned) {
            setState(() => _money += earned);
          },
          onAPChanged: (newAP) {
            setState(() => _ap = newAP);
          },
        ),
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label,
    Color color, {
    VoidCallback? onPressed,
  }) {
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
      onPressed:
          onPressed ??
          () {
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
    _timeSyncTimer?.cancel();
    _pulseCtrl.dispose();
    _phoneAnimCtrl.dispose();
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

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (_isPhoneOpen) {
          _closePhone();
        } else {
          final shouldExit = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                '앱 종료',
                style: TextStyle(
                  color: Color(0xFF2D3142),
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: const Text(
                '게임을 정말 종료하시겠습니까?',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text(
                    '취소',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text(
                    '종료',
                    style: TextStyle(
                      color: Color(0xFFE85D75),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );

          if (shouldExit ?? false) {
            SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
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

            // 2. 📱 핸드폰 히트박스 (다각형 — 배경 속 기울어진 스마트폰과 정확히 일치)
            if (_hasPhoneInBackground() && !_isPhoneOpen)
              Builder(
                builder: (context) {
                  final hitbox = _getPhoneHitbox(screenWidth, screenHeight);
                  if (hitbox.isEmpty) return const SizedBox.shrink();
                  final bbox = hitbox.boundingBox;
                  // 다각형 꼭짓점을 Positioned 기준 로컬 좌표로 변환
                  final localPoly = hitbox.polygon
                      .map((p) => Offset(p.dx - bbox.left, p.dy - bbox.top))
                      .toList();
                  return Positioned(
                    left: bbox.left,
                    top: bbox.top,
                    width: bbox.width,
                    height: bbox.height,
                    child: GestureDetector(
                      onTap: _openPhone,
                      behavior: HitTestBehavior.deferToChild,
                      child: AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (_, child) {
                          final pulse = 0.6 + 0.4 * _pulseCtrl.value;
                          return CustomPaint(
                            size: Size(bbox.width, bbox.height),
                            painter: _PhoneHitboxPainter(
                              polygon: localPoly,
                              cornerRadius: hitbox.cornerRadius,
                              pulse: pulse,
                              glowColor: hitbox.glowColor,
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),

            // 4-1. 🎯 시간대별 행동 버튼 (핸드폰 제외한 기존 버튼들)
            if (!_isPhoneOpen)
              Positioned(
                bottom: 50,
                left: 20,
                right: 20,
                child: _buildDynamicButtons(),
              ),

            // 5. 💰 상단 상태창
            Positioned(
              top: 50,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
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

            // 6. 📱 스마트폰 오버레이 (통합 연속 연출)
            if (_isPhoneOpen)
              AnimatedBuilder(
                animation: _phoneAnimCtrl,
                builder: (context, child) {
                  // Interval 1: 0.0~0.4 (바닥에서 중간 크기로 등장)
                  final t1 = CurvedAnimation(
                    parent: _phoneAnimCtrl,
                    curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
                  ).value;

                  // Interval 2: 0.4~1.0 (중간 크기에서 풀스크린으로 확장)
                  final t2 = CurvedAnimation(
                    parent: _phoneAnimCtrl,
                    curve: const Interval(0.2, 1.0, curve: Curves.easeOutQuart),
                  ).value;

                  // 중간 단계 크기 (82% x 78%)
                  final midW = screenWidth * 0.82;
                  final midH = screenHeight * 0.78;

                  // 1. 크기 계산: 바닥(0) -> 중간(t1) -> 풀스크린(t2)
                  // t2가 0일 때는 midW 유지, t2가 1일 때는 screenWidth
                  final currentW = midW + (screenWidth - midW) * t2;
                  final currentH = midH + (screenHeight - midH) * t2;

                  // 2. 위치 계산:
                  final centerX = (screenWidth - currentW) / 2;
                  final midY = (screenHeight - midH) / 2; // 중간 단계의 정중앙 Y

                  // t1 단계: 화면 아래(screenHeight)에서 midY까지 올라옴
                  // t2 단계: midY에서 0.0(풀스크린 시작점)까지 확장됨
                  final startY = screenHeight;
                  final currentY = (startY + (midY - startY) * t1) * (1 - t2);

                  // 3. 스타일 보간
                  final radius = 32.0 * (1 - t2);
                  final opacity = (t1 / 0.2).clamp(0.0, 1.0); // 아주 살짝 페이드인

                  return Positioned(
                    left: centerX,
                    top: currentY,
                    child: Opacity(
                      opacity: opacity,
                      child: Container(
                        width: currentW,
                        height: currentH,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(radius),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: 0.2 * (1 - t2),
                              ),
                              blurRadius: 40 * (1 - t2),
                              offset: Offset(0, 14 * (1 - t2)),
                            ),
                          ],
                        ),
                        child: PhoneScreen(
                          timeOffset: _timeOffset,
                          onClose: _closePhone,
                          currentZoneCode: _getZoneCode(_serverHour),
                          apps: buildDefaultApps(
                            callbacks: {
                              '앨범': () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const AlbumHomeScreen(),
                                  ),
                                );
                              },
                              '캘린더': () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const CalendarHomeScreen(),
                                  ),
                                );
                              },
                              'E-class': () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => MinigameScreen(
                                      actionPoints: _studyAp,
                                      currentDay: _serverDay,
                                      playerName: _playerName,
                                      onClose: () =>
                                          Navigator.of(context).pop(),
                                      onRewardEarned: (earned) {
                                        setState(() => _money += earned);
                                      },
                                      onAPChanged: (newAP) {
                                        setState(() => _studyAp = newAP);
                                      },
                                    ),
                                  ),
                                );
                              },
                              '선물샵': () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => GiftAppScreen(
                                      initialMoney: _money,
                                      currentZoneCode: _getZoneCode(_serverHour),
                                      onGiftSent: (newMoney) {
                                        setState(() {
                                          _money = newMoney;
                                        });
                                      },
                                      onGoToChat: (heroineName, day, zone) {
                                        Navigator.of(context).pop();
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => ChatRoomScreen(
                                              heroineName: heroineName,
                                              currentDay: day,
                                              currentTimeZone: zone,
                                            ),
                                          ),
                                        ).then((_) {
                                          _loadLobbyData();
                                        });
                                      },
                                    ),
                                  ),
                                );
                              },
                              '메신저': () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ChatListScreen(
                                      currentZoneCode: _getZoneCode(_serverHour),
                                    ),
                                  ),
                                );
                              },
                            },
                          ),

                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // 💡 스토리 완료 후 일러스트 해금 팝업 연출 (10년차 디자이너 연출 기법 적용)
  void _showIllustrationUnlockOverlay(BuildContext context, String unlockedId) {
    AlbumItem? unlockedItem;
    for (var list in kHeroineAlbumMetadata.values) {
      for (var item in list) {
        if (item.id == unlockedId) {
          unlockedItem = item;
          break;
        }
      }
      if (unlockedItem != null) break;
    }

    if (unlockedItem == null) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "unlock_overlay",
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (context, anim1, anim2) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (context, anim1, anim2, child) {
        final scale = CurvedAnimation(
          parent: anim1,
          curve: Curves.easeOutBack,
        ).value;
        final opacity = CurvedAnimation(
          parent: anim1,
          curve: Curves.easeInOut,
        ).value;

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12 * opacity, sigmaY: 12 * opacity),
          child: Opacity(
            opacity: opacity,
            child: Scaffold(
              backgroundColor: Colors.black.withValues(alpha: 0.55),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 황금빛 타이틀 데코
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                        ).createShader(bounds),
                        child: const Text(
                          "NEW ILLUSTRATION",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "UNLOCKED!",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 30),
                      // 일러스트 카드 썸네일 (바운스 스케일링 연계)
                      Transform.scale(
                        scale: scale,
                        child: Container(
                          width: double.infinity,
                          height: 320,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFFFFD700,
                                ).withValues(alpha: 0.2),
                                blurRadius: 40,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.asset(
                            unlockedItem!.imagePath,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // 일러스트 제목
                      Text(
                        unlockedItem.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Day ${unlockedItem.unlockDay} ${unlockedItem.unlockZone} 에피소드 해금",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 40),
                      // 하단 버튼 구성
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 닫기 버튼
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                            child: Text(
                              "나중에 보기",
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // 앨범 바로가기 버튼
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop(); // 팝업 닫기
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const AlbumHomeScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF5F4A41),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              "앨범으로 이동",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 📱 다각형 기반 핸드폰 히트박스 페인터 (배경 조명과 어우러지는 앰비언트 글로우)
class _PhoneHitboxPainter extends CustomPainter {
  final List<Offset> polygon;
  final double cornerRadius;
  final double pulse;
  final Color glowColor;

  _PhoneHitboxPainter({
    required this.polygon,
    required this.cornerRadius,
    required this.pulse,
    required this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (polygon.length < 3) return;

    final path = _buildRoundedPolygonPath(polygon, cornerRadius);

    // 1️⃣ 은은한 아주 연한 내부 채움 (스마트폰 영역을 암시하는 정도)
    canvas.drawPath(
      path,
      Paint()
        ..color = glowColor.withValues(alpha: (0.03 * pulse).clamp(0.0, 1.0)),
    );

    // 2️⃣ 가장 바깥의 넓게 퍼지는 아우라 네온 글로우 (가장 굵고 흐릿한 선)
    canvas.drawPath(
      path,
      Paint()
        ..color = glowColor.withValues(alpha: (0.35 * pulse).clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9.0 * pulse
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8.0 * pulse),
    );

    // 3️⃣ 중간 강도의 응축된 네온 글로우 (적당히 굵고 약간 흐릿한 선)
    canvas.drawPath(
      path,
      Paint()
        ..color = glowColor.withValues(alpha: (0.55 * pulse).clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0 * pulse
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3.5 * pulse),
    );

    // 4️⃣ 가장 중심에서 밝게 빛나는 코어 핵심 테두리 (가장 밝고 뚜렷한 선)
    // 테두리가 자체 발광하는 고광도 느낌을 주기 위해 흰색을 70% 섞은 극도로 밝은 빛으로 표현합니다.
    final coreColor = Color.lerp(glowColor, Colors.white, 0.7) ?? Colors.white;
    canvas.drawPath(
      path,
      Paint()
        ..color = coreColor.withValues(alpha: (0.95 * pulse).clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  /// 각 꼭짓점을 둥글게 깎은 다각형 경로 생성 (Quadratic Bézier)
  Path _buildRoundedPolygonPath(List<Offset> pts, double radius) {
    final path = Path();
    final n = pts.length;

    for (int i = 0; i < n; i++) {
      final prev = pts[(i - 1 + n) % n];
      final curr = pts[i];
      final next = pts[(i + 1) % n];

      final toPrev = prev - curr;
      final toNext = next - curr;
      final distPrev = toPrev.distance;
      final distNext = toNext.distance;

      final r = math.min(radius, math.min(distPrev / 2, distNext / 2));

      final startPt = curr + toPrev * (r / distPrev);
      final endPt = curr + toNext * (r / distNext);

      if (i == 0) {
        path.moveTo(startPt.dx, startPt.dy);
      } else {
        path.lineTo(startPt.dx, startPt.dy);
      }
      path.quadraticBezierTo(curr.dx, curr.dy, endPt.dx, endPt.dy);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _PhoneHitboxPainter old) => old.pulse != pulse;

  @override
  bool hitTest(Offset position) {
    if (polygon.length < 3) return false;
    final path = Path()..addPolygon(polygon, true);
    return path.contains(position);
  }
}

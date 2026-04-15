import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import '../../core/api_client.dart';
import '../story/story_screen.dart';
import '../lobby/lobby_screen.dart';

// ══════════════════════════════════════════════════════════════════════════════
// 폰트 상수
// ══════════════════════════════════════════════════════════════════════════════
class AppFonts {
  AppFonts._();
  static const String title = 'YChoiAe'; // Y최애TTF Bold
}

// ══════════════════════════════════════════════════════════════════════════════
// 시간대 enum
// ══════════════════════════════════════════════════════════════════════════════
enum TimePeriod { morning, day, night, dawn }

TimePeriod _periodOf(int hour) {
  if (hour >= 6 && hour < 12) return TimePeriod.morning;
  if (hour >= 12 && hour < 18) return TimePeriod.day;
  if (hour >= 18) return TimePeriod.night;
  return TimePeriod.dawn;
}

// ══════════════════════════════════════════════════════════════════════════════
// 파티클 데이터 클래스
// ══════════════════════════════════════════════════════════════════════════════
class _StarData {
  final double x, y, size, phase, speed;
  const _StarData(this.x, this.y, this.size, this.phase, this.speed);
}

class _PetalData {
  final double startX, startOffset, speed, swayAmp, swayFreq, size, rotation;
  final Color color;
  const _PetalData(
    this.startX,
    this.startOffset,
    this.speed,
    this.swayAmp,
    this.swayFreq,
    this.size,
    this.rotation,
    this.color,
  );
}

class _CloudData {
  final double y, widthFrac, height, opacity, speed, startOffset;
  const _CloudData(
    this.y,
    this.widthFrac,
    this.height,
    this.opacity,
    this.speed,
    this.startOffset,
  );
}

class _FireflyData {
  final double baseX, baseY, dxAmp, dyAmp, dxFreq, dyFreq, size;
  const _FireflyData(
    this.baseX,
    this.baseY,
    this.dxAmp,
    this.dyAmp,
    this.dxFreq,
    this.dyFreq,
    this.size,
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// 파티클 CustomPainter
// ══════════════════════════════════════════════════════════════════════════════
class _ParticlePainter extends CustomPainter {
  final TimePeriod period;
  final double anim; // 0.0 ~ 1.0 반복
  final List<_StarData> stars;
  final List<_PetalData> petals;
  final List<_CloudData> clouds;
  final List<_FireflyData> fireflies;

  const _ParticlePainter({
    required this.period,
    required this.anim,
    required this.stars,
    required this.petals,
    required this.clouds,
    required this.fireflies,
  });

  @override
  void paint(Canvas canvas, Size size) {
    switch (period) {
      case TimePeriod.morning:
        _paintMorning(canvas, size);
      case TimePeriod.day:
        _paintDay(canvas, size);
      case TimePeriod.night:
        _paintNight(canvas, size);
      case TimePeriod.dawn:
        _paintDawn(canvas, size);
    }
  }

  // ── 아침: 벚꽃 꽃잎 + 황금 반짝임 ──────────────────────────────────────
  void _paintMorning(Canvas canvas, Size size) {
    // 황금 반짝임
    for (final s in stars) {
      final opacity = (0.4 + 0.6 * sin(anim * pi * 2 * s.speed + s.phase))
          .clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height * 0.55),
        s.size,
        Paint()
          ..color = const Color(0xFFFFD700).withValues(alpha: opacity * 0.8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
    // 벚꽃 꽃잎
    for (final p in petals) {
      final progress = (p.startOffset + anim * p.speed) % 1.0;
      final y = progress * (size.height + 40) - 20;
      final x =
          p.startX * size.width +
          sin(anim * p.swayFreq * pi * 2) * p.swayAmp * size.width * 0.06;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation + anim * pi * 2);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: p.size,
          height: p.size * 0.65,
        ),
        Paint()..color = p.color.withValues(alpha: 0.88),
      );
      canvas.restore();
    }
  }

  // ── 낮: 구름 + 하늘 반짝임 ──────────────────────────────────────────────
  void _paintDay(Canvas canvas, Size size) {
    for (final c in clouds) {
      // x: 1.3 → -0.3 방향으로 drift (속도/위상 적용)
      final xFrac = 1.3 - ((c.startOffset + anim * c.speed) % 1.6);
      final x = xFrac * size.width;
      final y = c.y * size.height;
      final w = c.widthFrac * size.width;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - w / 2, y - c.height / 2, w, c.height),
          Radius.circular(c.height / 2),
        ),
        Paint()
          ..color = Colors.white.withValues(alpha: c.opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
    for (final s in stars) {
      final opacity = (0.3 + 0.7 * sin(anim * pi * 2 * s.speed + s.phase))
          .clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height * 0.55),
        s.size,
        Paint()
          ..color = const Color(0xFFFFD700).withValues(alpha: opacity * 0.65),
      );
    }
  }

  // ── 밤: 별 + 유성 + 보라빛 파티클 ──────────────────────────────────────
  void _paintNight(Canvas canvas, Size size) {
    // 별
    for (final s in stars) {
      final opacity = (0.3 + 0.7 * sin(anim * pi * 2 * s.speed + s.phase))
          .clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height * 0.65),
        s.size,
        Paint()
          ..color = Colors.white.withValues(alpha: opacity)
          ..maskFilter = s.size > 1.8
              ? const MaskFilter.blur(BlurStyle.normal, 1)
              : null,
      );
    }
    // 유성 (12초 주기 중 초반 8%에만 표시)
    if (anim < 0.08) {
      final t = anim / 0.08;
      final tailLen = 60.0 * t;
      final opacity = (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.0, 1.0);
      final sx = size.width * (0.12 + t * 0.28);
      final sy = size.height * (0.06 + t * 0.14);
      canvas.drawLine(
        Offset(sx, sy),
        Offset(sx - tailLen * 0.85, sy - tailLen * 0.5),
        Paint()
          ..color = Colors.white.withValues(alpha: opacity)
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
    // 보라빛 파티클
    for (final p in petals) {
      final progress = (p.startOffset + anim * p.speed) % 1.0;
      final y = progress * (size.height + 20) - 10;
      final x =
          p.startX * size.width +
          sin(anim * p.swayFreq * pi * 2) * p.swayAmp * size.width * 0.07;
      canvas.drawCircle(
        Offset(x, y),
        p.size,
        Paint()..color = p.color.withValues(alpha: 0.7),
      );
    }
  }

  // ── 새벽: 희미한 별 + 반딧불 ──────────────────────────────────────────
  void _paintDawn(Canvas canvas, Size size) {
    for (final s in stars) {
      final opacity = (0.15 + 0.3 * sin(anim * pi * 2 * s.speed + s.phase))
          .clamp(0.0, 0.5);
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height * 0.58),
        s.size,
        Paint()..color = const Color(0xFFD2E1FF).withValues(alpha: opacity),
      );
    }
    for (final ff in fireflies) {
      final x =
          ff.baseX * size.width + sin(anim * pi * 2 * ff.dxFreq) * ff.dxAmp;
      final y =
          ff.baseY * size.height + cos(anim * pi * 2 * ff.dyFreq) * ff.dyAmp;
      final glow = (0.45 + 0.55 * sin(anim * pi * 2 * ff.dyFreq + 1.0)).clamp(
        0.0,
        1.0,
      );
      canvas.drawCircle(
        Offset(x, y),
        ff.size * 2.8,
        Paint()
          ..color = const Color(0xFF8CC3FF).withValues(alpha: glow * 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
      canvas.drawCircle(
        Offset(x, y),
        ff.size,
        Paint()..color = const Color(0xFF8CC3FF).withValues(alpha: glow * 0.95),
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) =>
      old.anim != anim || old.period != period;
}

// ══════════════════════════════════════════════════════════════════════════════
// TitleScreen
// ══════════════════════════════════════════════════════════════════════════════
class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key});

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

enum TitleState { loading, needLogin, readyToStart }

class _TitleScreenState extends State<TitleScreen>
    with TickerProviderStateMixin {
  TitleState _state = TitleState.loading;

  // 에뮬레이터 시스템 클럭이 UTC 기준인 경우를 대비해 KST(+9) 강제 적용
  static DateTime get _kstNow =>
      DateTime.now().toUtc().add(const Duration(hours: 9));

  DateTime _now = _kstNow;
  TimePeriod _period = TimePeriod.night;
  Timer? _clockTimer;

  // ── 애니메이션 컨트롤러 ──
  late final AnimationController _floatCtrl; // 타이틀 떠오르기
  late final AnimationController _blinkCtrl; // 하단 텍스트 깜빡임
  late final AnimationController _heartCtrl; // ♡ 박동
  late final AnimationController _particleCtrl; // 파티클 (12초 주기)
  late final AnimationController _celestialCtrl; // 해/달 발광 (3.5초 주기)

  // ── 파티클 데이터 ──
  final _rng = Random(42);
  List<_StarData> _stars = [];
  List<_PetalData> _petals = [];
  List<_CloudData> _clouds = [];
  List<_FireflyData> _fireflies = [];

  // ── 다이얼로그용 컨트롤러 ──
  final TextEditingController _bugReportCtrl = TextEditingController();
  final TextEditingController _adminKeyCtrl = TextEditingController(
    text: "여기에_어드민키_입력",
  );
  final TextEditingController _offlineDaysCtrl = TextEditingController(
    text: "1",
  );
  final TextEditingController _cheatHourCtrl = TextEditingController(
    text: "14",
  );

  // ── 초기화 ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _period = _periodOf(_now.hour);
    _generateParticles(_period);
    _checkAutoLogin();

    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    )..repeat(reverse: true);

    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _heartCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _celestialCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat(reverse: true);

    // ── 1초마다 KST 시계 갱신 + 시간대 감지 ──
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final now = _kstNow; // 항상 KST 기준
      final newPeriod = _periodOf(now.hour);
      if (newPeriod != _period) {
        _generateParticles(newPeriod);
        setState(() {
          _now = now;
          _period = newPeriod;
        });
      } else {
        setState(() => _now = now);
      }
    });
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    _blinkCtrl.dispose();
    _heartCtrl.dispose();
    _particleCtrl.dispose();
    _celestialCtrl.dispose();
    _clockTimer?.cancel();
    _bugReportCtrl.dispose();
    _adminKeyCtrl.dispose();
    _offlineDaysCtrl.dispose();
    _cheatHourCtrl.dispose();
    super.dispose();
  }

  // ── 파티클 생성 ────────────────────────────────────────────────────────
  void _generateParticles(TimePeriod period) {
    double r() => _rng.nextDouble();
    double rr(double a, double b) => a + r() * (b - a);

    switch (period) {
      case TimePeriod.morning:
        _stars = List.generate(
          12,
          (_) =>
              _StarData(r(), r() * 0.55, rr(1.5, 3.0), rr(0, pi * 2), rr(1, 3)),
        );
        _petals = List.generate(20, (_) {
          final colors = [
            const Color(0xFFFFCDD2),
            const Color(0xFFF8BBD9),
            const Color(0xFFFFB3BA),
            const Color(0xFFFFD1DC),
          ];
          return _PetalData(
            r(),
            r(),
            rr(0.55, 1.4),
            rr(0.6, 1.8),
            rr(0.5, 2.0),
            rr(6, 13),
            rr(0, pi * 2),
            colors[_rng.nextInt(colors.length)],
          );
        });
        _clouds = [];
        _fireflies = [];

      case TimePeriod.day:
        _stars = List.generate(
          22,
          (_) => _StarData(
            r(),
            r() * 0.55,
            rr(1.2, 2.8),
            rr(0, pi * 2),
            rr(1, 3.5),
          ),
        );
        _petals = [];
        _clouds = List.generate(
          4,
          (i) => _CloudData(
            rr(0.07, 0.38),
            rr(0.18, 0.30),
            rr(20, 38),
            rr(0.65, 0.85),
            rr(0.35, 0.65),
            r(),
          ),
        );
        _fireflies = [];

      case TimePeriod.night:
        _stars = List.generate(
          75,
          (_) => _StarData(
            r(),
            r() * 0.65,
            rr(0.5, 2.5),
            rr(0, pi * 2),
            rr(0.3, 1.0),
          ),
        );
        _petals = List.generate(18, (_) {
          final ri = _rng.nextInt(50);
          final g = 110 + ri;
          return _PetalData(
            r(),
            r(),
            rr(0.3, 0.8),
            rr(0.8, 2.2),
            rr(0.3, 1.0),
            rr(1.5, 3.2),
            0,
            Color.fromARGB(178, 160 + _rng.nextInt(50), g, 255),
          );
        });
        _clouds = [];
        _fireflies = [];

      case TimePeriod.dawn:
        _stars = List.generate(
          48,
          (_) => _StarData(
            r(),
            r() * 0.58,
            rr(0.5, 2.0),
            rr(0, pi * 2),
            rr(0.5, 1.5),
          ),
        );
        _petals = [];
        _clouds = [];
        _fireflies = List.generate(
          14,
          (_) => _FireflyData(
            rr(0.05, 0.92),
            rr(0.20, 0.82),
            rr(15, 55),
            rr(12, 48),
            rr(0.18, 0.80),
            rr(0.18, 0.75),
            rr(1.8, 3.2),
          ),
        );
    }
  }

  // ── 배경 그라디언트 (_now.hour 직접 계산 → 항상 현재 시간 반영) ─────────
  LinearGradient _getBgGradient() {
    final period = _periodOf(_now.hour);
    switch (period) {
      case TimePeriod.morning:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFE8401A),
            Color(0xFFF06030),
            Color(0xFFFF8C55),
            Color(0xFFFFCBA4),
            Color(0xFFFFF5EC),
          ],
          stops: [0.0, 0.08, 0.20, 0.55, 1.0],
        );
      case TimePeriod.day:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0D6EDA),
            Color(0xFF2E8BE8),
            Color(0xFF5AAFF5),
            Color(0xFF90CDF4),
            Color(0xFFEBF6FD),
          ],
          stops: [0.0, 0.18, 0.38, 0.58, 1.0],
        );
      case TimePeriod.night:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF080018),
            Color(0xFF2A1560),
            Color(0xFF3D1255),
            Color(0xFF5E1A50),
            Color(0xFF3A0840),
          ],
          stops: [0.0, 0.38, 0.58, 0.80, 1.0],
        );
      case TimePeriod.dawn:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF000018),
            Color(0xFF080F30),
            Color(0xFF120840),
            Color(0xFF0A0520),
            Color(0xFF050010),
          ],
          stops: [0.0, 0.38, 0.60, 0.82, 1.0],
        );
    }
  }

  // ── 해/달 위젯 ─────────────────────────────────────────────────────────
  Widget _buildCelestial() {
    switch (_period) {
      case TimePeriod.morning:
        // 태양 (우상단)
        return Positioned(
          top: MediaQuery.of(context).size.height * 0.07,
          right: MediaQuery.of(context).size.width * 0.10,
          child: AnimatedBuilder(
            animation: _celestialCtrl,
            builder: (_, child) {
              final pulse = 0.75 + 0.25 * _celestialCtrl.value;
              return Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    center: Alignment(-0.3, -0.3),
                    colors: [
                      Color(0xFFFFF9C4),
                      Color(0xFFFFD54F),
                      Color(0xFFFF8F00),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(
                        0xFFFFDC00,
                      ).withValues(alpha: 0.55 * pulse),
                      blurRadius: 30 * pulse,
                      spreadRadius: 4,
                    ),
                    BoxShadow(
                      color: const Color(
                        0xFFFF8C00,
                      ).withValues(alpha: 0.3 * pulse),
                      blurRadius: 60 * pulse,
                    ),
                  ],
                ),
              );
            },
          ),
        );

      case TimePeriod.night:
        // 밝은 달 (우상단)
        return Positioned(
          top: MediaQuery.of(context).size.height * 0.07,
          right: MediaQuery.of(context).size.width * 0.10,
          child: AnimatedBuilder(
            animation: _celestialCtrl,
            builder: (_, child) {
              final glow = 0.7 + 0.3 * _celestialCtrl.value;
              return Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    center: Alignment(-0.3, -0.3),
                    colors: [
                      Color(0xFFFFFDE7),
                      Color(0xFFFFF9C4),
                      Color(0xFFFFF176),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(
                        0xFFFFF9C4,
                      ).withValues(alpha: 0.4 * glow),
                      blurRadius: 28 * glow,
                      spreadRadius: 3,
                    ),
                    BoxShadow(
                      color: const Color(
                        0xFFB0BFF0,
                      ).withValues(alpha: 0.2 * glow),
                      blurRadius: 50 * glow,
                    ),
                  ],
                ),
              );
            },
          ),
        );

      case TimePeriod.dawn:
        // 희미한 달 (좌상단)
        return Positioned(
          top: MediaQuery.of(context).size.height * 0.08,
          left: MediaQuery.of(context).size.width * 0.09,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.3, -0.3),
                colors: [
                  const Color(0xFFDCE1FF).withValues(alpha: 0.9),
                  const Color(0xFFAAB4E1).withValues(alpha: 0.6),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFC8D2FF).withValues(alpha: 0.25),
                  blurRadius: 16,
                ),
              ],
            ),
          ),
        );

      case TimePeriod.day:
        return const SizedBox.shrink();
    }
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  // ── 로그인 관련 ─────────────────────────────────────────────────────────
  Future<void> _checkAutoLogin() async {
    final userId = await ApiClient().storage.read(key: 'user_id');
    final token = await ApiClient().storage.read(key: 'access_token');
    if (userId != null && token != null) {
      try {
        final res = await ApiClient().dio.post(
          '/login',
          queryParameters: {'user_id': userId},
        );
        if (res.statusCode == 200 && res.data['status'] == 'success') {
          await ApiClient().storage.write(
            key: 'access_token',
            value: res.data['access_token'],
          );
          if (mounted) setState(() => _state = TitleState.readyToStart);
          return;
        }
      } catch (e) {
        debugPrint("🚨 자동 로그인 실패: $e");
      }
    }
    if (mounted) setState(() => _state = TitleState.needLogin);
  }

  Future<void> _guestLogin() async {
    setState(() => _state = TitleState.loading);
    try {
      final res = await ApiClient().dio.post('/auth/guest-login');
      if (res.statusCode == 200) {
        await ApiClient().storage.write(
          key: 'access_token',
          value: res.data['access_token'],
        );
        await ApiClient().storage.write(
          key: 'user_id',
          value: res.data['user_id'],
        );
        debugPrint("✅ 게스트 로그인 성공 → Intro1 이동");
        _goToIntro1();
      }
    } on DioException catch (e) {
      debugPrint("🚨 게스트 로그인 실패 (서버 미실행?): ${e.response?.data ?? e.message}");
      // 서버 연결 불가(오프라인/개발 중)인 경우에도 Intro1 진입 허용
      if (!mounted) return;
      final isConnectionError =
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout;
      if (isConnectionError) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('서버 연결 불가 — 오프라인 게스트로 진입합니다.'),
            backgroundColor: Color(0xFF444466),
            duration: Duration(seconds: 2),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 600));
        _goToIntro1();
      } else {
        setState(() => _state = TitleState.needLogin);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '로그인 실패: ${e.response?.data?['detail'] ?? e.message ?? '알 수 없는 오류'}',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _goToIntro1() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const StoryScreen(storyId: 'intro_1_prologue', storyTicket: ''),
      ),
    );
  }

  Future<void> _checkStoryStatus() async {
    setState(() => _state = TitleState.loading);
    try {
      final res = await ApiClient().dio.get('/check-story');
      if (res.statusCode == 200 && mounted) {
        final autoPlay = res.data['auto_play_story'];
        if (autoPlay['is_available'] == true) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => StoryScreen(
                storyId: autoPlay['story_id'],
                storyTicket: autoPlay['story_ticket'],
                heroineName: autoPlay['heroine_name'],
              ),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LobbyScreen()),
          );
        }
      }
    } on DioException catch (e) {
      debugPrint("🚨 스토리 체크 실패: ${e.response?.data ?? e.message}");
      if (mounted) setState(() => _state = TitleState.readyToStart);
    }
  }

  // ── 다이얼로그들 ────────────────────────────────────────────────────────

  // START → 로그인 선택
  void _showLoginDialog() {
    if (_state == TitleState.readyToStart) {
      _checkStoryStatus();
      return;
    }
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (ctx) => _GlassDialog(
        children: [
          const Text(
            '로그인',
            style: TextStyle(
              fontFamily: AppFonts.title,
              color: Colors.white,
              fontSize: 22,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '시작하기 전에 로그인해주세요.',
            style: TextStyle(color: Color(0x99FFFFFF), fontSize: 12),
          ),
          const SizedBox(height: 28),
          _DialogButton(
            icon: Icons.person_outline,
            label: '게스트로 시작하기',
            onTap: () {
              Navigator.pop(ctx); // 다이얼로그 먼저 닫기 (ctx 사용)
              _guestLogin();
            },
          ),
          const SizedBox(height: 14),
          _DialogButton(
            icon: Icons.g_mobiledata_rounded,
            label: '구글 계정으로 로그인',
            onTap: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('구글 로그인은 곧 지원될 예정입니다.'),
                  backgroundColor: Color(0xFF2A2A55),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              '취소',
              style: TextStyle(color: Color(0x80FFFFFF), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // CONFIG
  void _showConfigDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (ctx) => _GlassDialog(
        children: [
          const Icon(Icons.settings_outlined, color: Colors.white54, size: 38),
          const SizedBox(height: 14),
          const Text(
            'C O N F I G',
            style: TextStyle(
              fontFamily: AppFonts.title,
              color: Colors.white,
              fontSize: 18,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '설정 기능은 곧 업데이트 예정입니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0x80FFFFFF),
              fontSize: 12,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 22),
          _SettingRow(label: '음악 볼륨', value: '준비 중'),
          const SizedBox(height: 8),
          _SettingRow(label: '효과음 볼륨', value: '준비 중'),
          const SizedBox(height: 8),
          _SettingRow(label: '텍스트 속도', value: '준비 중'),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              '닫기',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // EXIT
  void _exitApp() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (ctx) => _GlassDialog(
        width: 270,
        children: [
          const Text(
            '게임을 종료할까요?',
            style: TextStyle(
              fontFamily: AppFonts.title,
              color: Colors.white,
              fontSize: 16,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    '취소',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    if (Platform.isAndroid) {
                      SystemNavigator.pop();
                    } else {
                      exit(0);
                    }
                  },
                  child: const Text(
                    '종료',
                    style: TextStyle(
                      color: Color(0xFFFF6B6B),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 버그 제보
  void _showBugReportDialog() {
    _bugReportCtrl.clear();
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (ctx) => _GlassDialog(
        children: [
          Row(
            children: const [
              Icon(
                Icons.bug_report_outlined,
                color: Color(0xFFFF6B6B),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                '버그 제보',
                style: TextStyle(
                  fontFamily: AppFonts.title,
                  color: Colors.white,
                  fontSize: 18,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '발견하신 버그나 불편사항을 알려주세요.',
            style: TextStyle(color: Color(0x80FFFFFF), fontSize: 12),
          ),
          const SizedBox(height: 18),
          Container(
            decoration: BoxDecoration(
              color: const Color(0x1AFFFFFF),
              border: Border.all(color: const Color(0x4DFFFFFF)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _bugReportCtrl,
              maxLines: 5,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                hintText: '버그 내용을 입력해주세요...',
                hintStyle: TextStyle(color: Color(0x4DFFFFFF)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(12),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    '취소',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              ),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0x33FFFFFF),
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0x7AFFFFFF)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () {
                    final text = _bugReportCtrl.text.trim();
                    Navigator.pop(ctx);
                    if (text.isNotEmpty) {
                      debugPrint("🐛 버그 제보: $text");
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('버그 제보가 접수되었습니다. 감사합니다!'),
                          backgroundColor: Color(0xFF2A5C2A),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  child: const Text('제출'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 어드민 패널 (버그 아이콘 롱프레스)
  void _showAdminPanel() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
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
              final adminKey = _adminKeyCtrl.text;
              final offlineDays = int.tryParse(_offlineDaysCtrl.text) ?? 0;
              final cheatHour = int.tryParse(_cheatHourCtrl.text) ?? 14;
              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
              setState(() => _state = TitleState.loading);
              try {
                final userId = await ApiClient().storage.read(key: 'user_id');
                if (userId == null) throw Exception("유저 ID 없음");
                final loginRes = await ApiClient().dio.post(
                  '/admin/login',
                  queryParameters: {
                    'user_id': userId,
                    'cheat_offline_days': offlineDays,
                  },
                  options: Options(headers: {'admin-key': adminKey}),
                );
                if (loginRes.data['status'] != 'success') {
                  throw Exception(loginRes.data['error_code'] ?? '어드민 로그인 실패');
                }
                await ApiClient().storage.write(
                  key: 'access_token',
                  value: loginRes.data['access_token'],
                );
                final storyRes = await ApiClient().dio.get(
                  '/admin/check-story',
                  queryParameters: {'cheat_hour': cheatHour},
                  options: Options(headers: {'admin-key': adminKey}),
                );
                if (storyRes.data['status'] != 'success') {
                  throw Exception(storyRes.data['error_code'] ?? '스토리 체크 실패');
                }
                final autoPlay = storyRes.data['auto_play_story'];
                if (!mounted) return;
                if (autoPlay['is_available'] == true) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StoryScreen(
                        storyId: autoPlay['story_id'],
                        storyTicket: autoPlay['story_ticket'],
                        heroineName: autoPlay['heroine_name'],
                      ),
                    ),
                  );
                } else {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LobbyScreen()),
                  );
                }
              } catch (e) {
                if (mounted) {
                  setState(() => _state = TitleState.readyToStart);
                  String msg = e.toString().replaceAll('Exception: ', '');
                  if (e is DioException) {
                    msg = e.response?.data?['error_code'] ?? '서버 통신 오류';
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('치트 실패: $msg'),
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
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('닫기', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  // ── build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 배경 그라디언트 (매 초 setState → _now.hour 기반으로 즉시 반영) ──
          Container(decoration: BoxDecoration(gradient: _getBgGradient())),

          // ── 비네트 ──
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.15,
                colors: [Colors.transparent, Color(0x8C000000)],
                stops: [0.45, 1.0],
              ),
            ),
          ),

          // ── 파티클 레이어 ──
          AnimatedBuilder(
            animation: _particleCtrl,
            builder: (context, unusedChild) => CustomPaint(
              painter: _ParticlePainter(
                period: _period,
                anim: _particleCtrl.value,
                stars: _stars,
                petals: _petals,
                clouds: _clouds,
                fireflies: _fireflies,
              ),
              size: Size.infinite,
            ),
          ),

          // ── 해/달 ──
          _buildCelestial(),

          // ── 좌상단 시계 ──
          Positioned(
            top: 22,
            left: 22,
            child: Text(
              _formatTime(_now),
              style: const TextStyle(
                fontFamily: AppFonts.title,
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
                shadows: [
                  Shadow(color: Color(0xA6FFFFFF), blurRadius: 14),
                  Shadow(color: Color(0x99000000), blurRadius: 4),
                ],
              ),
            ),
          ),

          // ── 메인 콘텐츠 ──
          if (_state == TitleState.loading)
            const Center(child: CircularProgressIndicator(color: Colors.white))
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 타이틀 float 애니메이션
                  AnimatedBuilder(
                    animation: _floatCtrl,
                    builder: (_, child) => Transform.translate(
                      offset: Offset(
                        0,
                        Tween<double>(begin: 0, end: -13)
                            .animate(
                              CurvedAnimation(
                                parent: _floatCtrl,
                                curve: Curves.easeInOut,
                              ),
                            )
                            .value,
                      ),
                      child: child,
                    ),
                    child: Column(
                      children: [
                        const Text(
                          '✦  L O V E  S T O R Y  ✦',
                          style: TextStyle(
                            fontFamily: AppFonts.title,
                            color: Color(0xB8FFFFFF),
                            fontSize: 13,
                            letterSpacing: 5,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          '진짜로\n연애할 수 있을까요?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: AppFonts.title,
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            height: 1.45,
                            letterSpacing: 2,
                            shadows: [
                              Shadow(color: Color(0x8CFFFFFF), blurRadius: 25),
                              Shadow(color: Color(0x59FFC8D2), blurRadius: 55),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── 구분선 ──
                  SizedBox(
                    width: 220,
                    child: Row(
                      children: [
                        Expanded(child: _dividerLine()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: AnimatedBuilder(
                            animation: _heartCtrl,
                            builder: (_, child) {
                              final t = _heartCtrl.value;
                              final scale = t < 0.3
                                  ? 1.0 + 0.25 * (t / 0.3)
                                  : t < 0.6
                                  ? 1.25 - 0.35 * ((t - 0.3) / 0.3)
                                  : 0.9 + 0.1 * ((t - 0.6) / 0.4);
                              return Transform.scale(
                                scale: scale,
                                child: child,
                              );
                            },
                            child: const Text(
                              '♡',
                              style: TextStyle(
                                color: Color(0xB8FFFFFF),
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        Expanded(child: _dividerLine()),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── 버튼 ──
                  SizedBox(
                    width: 220,
                    child: Column(
                      children: [
                        _GlassButton(
                          label: 'S T A R T',
                          onTap: _showLoginDialog,
                        ),
                        const SizedBox(height: 14),
                        _GlassButton(
                          label: 'C O N F I G',
                          onTap: _showConfigDialog,
                        ),
                        const SizedBox(height: 14),
                        _GlassButton(label: 'E X I T', onTap: _exitApp),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // ── 하단 TAP TO BEGIN ──
          if (_state != TitleState.loading)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _blinkCtrl,
                builder: (_, child) => Opacity(
                  opacity: Tween<double>(begin: 0.35, end: 0.85)
                      .animate(
                        CurvedAnimation(
                          parent: _blinkCtrl,
                          curve: Curves.easeInOut,
                        ),
                      )
                      .value,
                  child: child,
                ),
                child: const Text(
                  'T A P  T O  B E G I N',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.title,
                    color: Colors.white,
                    fontSize: 11,
                    letterSpacing: 4,
                  ),
                ),
              ),
            ),

          // ── 우상단 버그 제보 아이콘 ──
          Positioned(
            top: 48,
            right: 16,
            child: GestureDetector(
              onTap: _showBugReportDialog,
              onLongPress: _showAdminPanel,
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(
                  Icons.bug_report_outlined,
                  color: Color(0x66FFFFFF),
                  size: 26,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dividerLine() => Container(
    height: 1,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.transparent, Color(0x80FFFFFF), Colors.transparent],
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// 공통 글래스 다이얼로그
// ══════════════════════════════════════════════════════════════════════════════
class _GlassDialog extends StatelessWidget {
  final List<Widget> children;
  final double width;

  const _GlassDialog({required this.children, this.width = 300});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 24),
        decoration: BoxDecoration(
          color: const Color(0xEA0D0E20),
          border: Border.all(color: const Color(0x7AFFFFFF), width: 1.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 글래스 버튼 (타이틀 화면)
// ══════════════════════════════════════════════════════════════════════════════
class _GlassButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _GlassButton({required this.label, required this.onTap});

  @override
  State<_GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<_GlassButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _pressed ? const Color(0x33FFFFFF) : const Color(0x1AFFFFFF),
          border: Border.all(
            color: _pressed ? const Color(0xD0FFFFFF) : const Color(0x7AFFFFFF),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(50),
          boxShadow: _pressed
              ? [
                  const BoxShadow(
                    color: Color(0x38FFFFFF),
                    blurRadius: 28,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: Text(
          widget.label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppFonts.title,
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
            shadows: [Shadow(color: Color(0x59000000), blurRadius: 3)],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 다이얼로그 내부 버튼
// ══════════════════════════════════════════════════════════════════════════════
class _DialogButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _DialogButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0x1AFFFFFF),
          border: Border.all(color: const Color(0x7AFFFFFF), width: 1.2),
          borderRadius: BorderRadius.circular(50),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white70, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                letterSpacing: 1,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CONFIG 설정 행
// ══════════════════════════════════════════════════════════════════════════════
class _SettingRow extends StatelessWidget {
  final String label;
  final String value;
  const _SettingRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x1AFFFFFF),
        border: Border.all(color: const Color(0x33FFFFFF)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0x60FFFFFF),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

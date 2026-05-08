import 'dart:async';
import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════════════════════
// 📱 앱 데이터 모델
// ══════════════════════════════════════════════════════════════════════════════

/// 스마트폰 홈 화면에 표시되는 개별 앱 정보.
/// [availableZones]를 통해 시간대별 활성/비활성을 제어할 수 있습니다.
///   zone codes: 0=새벽, 1=아침, 2=낮, 3=밤 (lobby_screen의 _getZoneCode와 동일)
class PhoneApp {
  final String name;
  final IconData icon;
  final List<Color> gradientColors;
  final VoidCallback? onTap;
  final Set<int>? availableZones; // null이면 모든 시간대에서 사용 가능

  const PhoneApp({
    required this.name,
    required this.icon,
    required this.gradientColors,
    this.onTap,
    this.availableZones,
  });

  bool isAvailable(int currentZoneCode) {
    if (availableZones == null) return true;
    return availableZones!.contains(currentZoneCode);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 📱 기본 앱 목록 (레퍼런스 기반 6개)
// ══════════════════════════════════════════════════════════════════════════════

/// 기본 앱 목록을 생성합니다. 각 앱의 [onTap]을 오버라이드하여 기능을 연결할 수 있습니다.
List<PhoneApp> buildDefaultApps({Map<String, VoidCallback?> callbacks = const {}}) {
  return [
    PhoneApp(
      name: '쇼핑',
      icon: Icons.shopping_bag_outlined,
      gradientColors: const [Color(0xFFFF8B86), Color(0xFFFF7276)],
      onTap: callbacks['쇼핑'],
    ),
    PhoneApp(
      name: 'E-class',
      icon: Icons.school_outlined,
      gradientColors: const [Color(0xFF75ADFF), Color(0xFF548EFF)],
      onTap: callbacks['E-class'],
    ),
    PhoneApp(
      name: '캘린더',
      icon: Icons.calendar_month_outlined,
      gradientColors: const [Color(0xFFFFC56F), Color(0xFFFFAF5D)],
      onTap: callbacks['캘린더'],
    ),
    PhoneApp(
      name: '앨범',
      icon: Icons.photo_library_outlined,
      gradientColors: const [Color(0xFF6AD8C3), Color(0xFF48C1B0)],
      onTap: callbacks['앨범'],
    ),
    PhoneApp(
      name: '메신저',
      icon: Icons.mail_outline_rounded,
      gradientColors: const [Color(0xFFA590FF), Color(0xFF8B76F6)],
      onTap: callbacks['메신저'],
    ),
    PhoneApp(
      name: '오늘의 운세',
      icon: Icons.star_rounded,
      gradientColors: const [Color(0xFFFF95C3), Color(0xFFFF79B0)],
      onTap: callbacks['오늘의 운세'],
    ),
  ];
}

// ══════════════════════════════════════════════════════════════════════════════
// 📱 PhoneScreen 위젯
// ══════════════════════════════════════════════════════════════════════════════

class PhoneScreen extends StatefulWidget {
  final Duration timeOffset;
  final VoidCallback onClose;
  final int currentZoneCode;
  final List<PhoneApp> apps;

  const PhoneScreen({
    super.key,
    required this.timeOffset,
    required this.onClose,
    required this.currentZoneCode,
    required this.apps,
  });

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  Timer? _clockTimer;
  DateTime _displayTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _updateClock();
    });
  }

  void _updateClock() {
    setState(() {
      _displayTime = DateTime.now().add(widget.timeOffset);
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  String _formatHour(int hour) {
    final h = hour % 12;
    return h == 0 ? '12' : h.toString();
  }

  String _formatMinute(int minute) => minute.toString().padLeft(2, '0');

  String _getMeridiem(int hour) => hour < 12 ? '오전' : '오후';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Stack(
        children: [
          // 메인 콘텐츠
          SafeArea(
            child: Column(
              children: [
                // ── 닫기 버튼 ──
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 18, right: 18),
                    child: GestureDetector(
                      onTap: widget.onClose,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.66),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFCEB4AC).withValues(alpha: 0.22),
                              blurRadius: 22,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            '×',
                            style: TextStyle(
                              fontSize: 22,
                              color: Color(0xC76D574A),
                              fontWeight: FontWeight.w300,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── 시계 ──
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Column(
                    children: [
                      Text(
                        _getMeridiem(_displayTime.hour),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xB85F4A41),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_formatHour(_displayTime.hour)}:${_formatMinute(_displayTime.minute)}',
                        style: const TextStyle(
                          fontSize: 72,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF5F4A41),
                          letterSpacing: -5,
                          height: 0.95,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // ── 앱 그리드 ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 2.2,
                    children: widget.apps.map((app) {
                      final isAvailable = app.isAvailable(widget.currentZoneCode);
                      return _AppTile(
                        app: app,
                        isAvailable: isAvailable,
                        onTap: () => _handleAppTap(app, isAvailable),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 40),

                // ── 하단 홈 인디케이터 ──
                Container(
                  width: 140,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5F4A41).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleAppTap(PhoneApp app, bool isAvailable) {
    if (!isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${app.name}은(는) 지금 이용할 수 없는 시간대입니다.'),
          backgroundColor: const Color(0xFF6D574A),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    if (app.onTap != null) {
      app.onTap!();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${app.name} - 준비 중입니다.'),
          backgroundColor: const Color(0xFF6D574A),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 📱 앱 타일 위젯
// ══════════════════════════════════════════════════════════════════════════════

class _AppTile extends StatelessWidget {
  final PhoneApp app;
  final bool isAvailable;
  final VoidCallback onTap;

  const _AppTile({
    required this.app,
    required this.isAvailable,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isAvailable ? 1.0 : 0.4,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFDEC7C4).withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              // 앱 아이콘
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: app.gradientColors,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: app.gradientColors.last.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  app.icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              // 앱 이름
              Expanded(
                child: Text(
                  app.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF5F4A41),
                    height: 1.25,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

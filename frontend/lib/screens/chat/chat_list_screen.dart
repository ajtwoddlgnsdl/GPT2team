import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import 'chat_room_screen.dart';

class ChatListScreen extends StatefulWidget {
  final int currentZoneCode; // 0=새벽, 1=아침, 2=낮, 3=밤
  const ChatListScreen({super.key, required this.currentZoneCode});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  bool _isLoading = true;
  List<dynamic> _heroines = [];
  String _currentZoneName = "낮";


  @override
  void initState() {
    super.initState();
    _fetchCalendarAndHeroines();
  }

  Future<void> _fetchCalendarAndHeroines() async {
    try {
      final response = await ApiClient().dio.get('/calendar/status');
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        final rawHeroines = response.data['heroines'] as List<dynamic>;
        final state = response.data['game_state'] as String;
        final zoneName = response.data['current_zone'] as String;

        setState(() {
          _currentZoneName = zoneName;


          // 💡 필터링 정책 적용:
          // MAIN 이나 END 상태인 경우 메인 히로인(is_main = true)만 대화방에 남겨둠
          if (state == "MAIN" || state == "END") {
            _heroines = rawHeroines.where((h) => h['is_main'] == true).toList();
          } else {
            // INTRO_2 등 공통 단계인 경우 전체 히로인 출력
            _heroines = rawHeroines;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("🚨 히로인 채팅 목록 조회 에러: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 히로인별 프로필 데코레이션 정보 반환
  Color _getHeroineColor(String name) {
    switch (name) {
      case "코토리":
        return const Color(0xFFFFC6FF); // 러블리 핑크
      case "이서연":
        return const Color(0xFF90E0EF); // 지적인 스카이블루
      case "리안":
        return const Color(0xFFFFB703); // 활기찬 오렌지/옐로
      default:
        return const Color(0xFFD3D3D3);
    }
  }

  String _getHeroineImage(String name) {
    switch (name) {
      case "코토리":
        return 'assets/images/character/코토리/코토리_기본.png';
      case "이서연":
        return 'assets/images/character/이서연/이서연_기본.png';
      case "리안":
        return 'assets/images/character/리안/리안_실외_화남.png'; // 기본 스탠딩 대용
      default:
        return '';
    }
  }

  String _getHeroineIntro(String name) {
    switch (name) {
      case "코토리":
        return '옆가게 코토리예요! 잘 부탁합니다!! 🌸';
      case "이서연":
        return '옆집 이서연입니다. 연락처 남겨드려요.';
      case "리안":
        return '민원 넣은거 너냐? 오토바이 소리 안 난다고 ㅡㅡ';
      default:
        return '안녕하세요!';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F5), // 따뜻한 미색 배경
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          '메신저',
          style: TextStyle(
            color: Color(0xFF5F4A41),
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF5F4A41), size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF5F4A41)))
          : _heroines.isEmpty
              ? const Center(
                  child: Text(
                    '연락처가 등록된 히로인이 없습니다.',
                    style: TextStyle(color: Colors.grey, fontSize: 15),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _heroines.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final h = _heroines[index];
                    final name = h['name'] as String;
                    final day = h['current_day'] as int;
                    final isMain = h['is_main'] as bool;
                    final avatarColor = _getHeroineColor(name);
                    final avatarImg = _getHeroineImage(name);
                    final intro = _getHeroineIntro(name);

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatRoomScreen(
                              heroineName: name,
                              currentDay: day,
                              currentTimeZone: _currentZoneName,
                            ),
                          ),
                        ).then((_) {
                          // 대화방을 나갔다 돌아오면 목록 최신화
                          _fetchCalendarAndHeroines();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFDEC7C4).withValues(alpha: 0.12),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // 🧍‍♀️ 히로인 아바타 원형 프레임
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: avatarColor.withValues(alpha: 0.25),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: avatarImg.isNotEmpty
                                  ? Image.asset(
                                      avatarImg,
                                      fit: BoxFit.cover,
                                      alignment: const Alignment(0, -0.4), // 얼굴 부분 매칭용 크롭 조정
                                      errorBuilder: (context, error, stackTrace) => Center(
                                        child: Text(
                                          name[0],
                                          style: TextStyle(
                                            color: _getHeroineColor(name),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 22,
                                          ),
                                        ),
                                      ),
                                    )
                                  : Center(
                                      child: Text(
                                        name[0],
                                        style: TextStyle(
                                          color: _getHeroineColor(name),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 22,
                                        ),
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 16),
                            // 이름 및 소개말
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF2D2420),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      // 메인 히로인 태그
                                      if (isMain)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE85D75).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'Main',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Color(0xFFE85D75),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    intro,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF8C7B75),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    maxLines: 1,
                                  ),
                                ],
                              ),
                            ),
                            // 스토리 일차 배지
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF5F4A41).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Day $day',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF5F4A41),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

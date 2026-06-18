import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../providers/chat_provider.dart';

class GiftAppScreen extends ConsumerStatefulWidget {
  final int initialMoney;
  final int currentZoneCode;
  final Function(int newMoney) onGiftSent;
  final Function(String heroineName, int day, String zone) onGoToChat;

  const GiftAppScreen({
    super.key,
    required this.initialMoney,
    required this.currentZoneCode,
    required this.onGiftSent,
    required this.onGoToChat,
  });

  @override
  ConsumerState<GiftAppScreen> createState() => _GiftAppScreenState();
}

class _GiftAppScreenState extends ConsumerState<GiftAppScreen> {
  bool _isLoading = true;
  bool _isSending = false;
  bool _isSuccess = false;

  List<dynamic> _gifts = [];
  List<dynamic> _heroines = [];
  String? _selectedGiftId;
  int _money = 0;

  // 성공 시 임시 저장할 데이터
  String _lastSentHeroine = "";
  String _lastSentGiftName = "";
  int _lastAffectionBoost = 0;
  int _lastHeroineDay = 1;
  String _lastHeroineZone = "낮";

  @override
  void initState() {
    super.initState();
    _money = widget.initialMoney;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final futures = await Future.wait([
        ApiClient().dio.get('/gifts'),
        ApiClient().dio.get('/calendar/status'),
      ]);

      final giftsRes = futures[0];
      final heroinesRes = futures[1];

      if (giftsRes.statusCode == 200 && giftsRes.data['status'] == 'success') {
        _gifts = giftsRes.data['gifts'] as List<dynamic>;
      }

      if (heroinesRes.statusCode == 200 && heroinesRes.data['status'] == 'success') {
        final rawHeroines = heroinesRes.data['heroines'] as List<dynamic>;
        final stateVal = heroinesRes.data['game_state'] as String;

        // 메인 대화방 필터와 동일하게 구성
        if (stateVal == "MAIN" || stateVal == "END") {
          _heroines = rawHeroines.where((h) => h['is_main'] == true).toList();
        } else {
          _heroines = rawHeroines;
        }
      }
    } catch (e) {
      debugPrint("🚨 선물앱 데이터 로드 에러: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  IconData _getGiftIcon(String id) {
    switch (id) {
      case "test_item":
        return Icons.circle_rounded;
      case "coffee":
        return Icons.local_cafe_outlined;
      case "chocolate":
        return Icons.cookie_outlined;
      case "macaron":
        return Icons.cake_outlined;
      case "teddy":
        return Icons.toys_outlined;
      case "perfume":
        return Icons.spa_outlined;
      default:
        return Icons.card_giftcard_outlined;
    }
  }

  List<Color> _getGiftGradient(String id) {
    switch (id) {
      case "test_item":
        return const [Color(0xFFFFC6FF), Color(0xFFFFD6A5)];
      case "coffee":
        return const [Color(0xFFE6CCB2), Color(0xFFB08968)];
      case "chocolate":
        return const [Color(0xFFFFADAD), Color(0xFFFF85A1)];
      case "macaron":
        return const [Color(0xFFFDFFB6), Color(0xFFFFD6A5)];
      case "teddy":
        return const [Color(0xFFCAFFBF), Color(0xFF96E072)];
      case "perfume":
        return const [Color(0xFFBDB2FF), Color(0xFF9BF6FF)];
      default:
        return const [Color(0xFFFFC6FF), Color(0xFFFFADAD)];
    }
  }

  Color _getHeroineAvatarBg(String name) {
    switch (name) {
      case "코토리":
        return const Color(0xFFFFC6FF).withValues(alpha: 0.25);
      case "이서연":
        return const Color(0xFF90E0EF).withValues(alpha: 0.25);
      case "리안":
        return const Color(0xFFFFB703).withValues(alpha: 0.25);
      default:
        return Colors.grey.shade200;
    }
  }

  String _getHeroineImage(String name) {
    switch (name) {
      case "코토리":
        return 'assets/images/character/코토리/코토리_기본.png';
      case "이서연":
        return 'assets/images/character/이서연/이서연_기본.png';
      case "리안":
        return 'assets/images/character/리안/리안_실외_화남.png';
      default:
        return '';
    }
  }

  Future<void> _sendGiftAction(String heroineName, Map<String, dynamic> gift) async {
    setState(() => _isSending = true);
    try {
      final response = await ApiClient().dio.post(
        '/gifts/send',
        data: {
          'heroine_name': heroineName,
          'gift_id': gift['id'],
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200 && response.data['status'] == 'success') {
        final currentMoney = response.data['current_money'] as int;
        final affectionBoost = response.data['affection_boost'] as int;
        final replyMessage = response.data['reply_message'] as String;
        final heroineCurrentDay = response.data['heroine_current_day'] as int;
        final currentZone = response.data['current_zone'] as String;

        // 1. 로비의 재화 갱신용 콜백 호출
        widget.onGiftSent(currentMoney);

        // 2. 로컬 SQLite DB에 메시지 2개 추가
        final chatNotifier = ref.read(chatRoomProvider.notifier);
        await chatNotifier.saveLocalMessage(heroineName, 'player', '[선물:${gift['id']}] ${gift['name']}을(를) 보냈습니다.');
        await chatNotifier.saveLocalMessage(heroineName, 'heroine', replyMessage, isRead: 0);

        setState(() {
          _money = currentMoney;
          _lastSentHeroine = heroineName;
          _lastSentGiftName = gift['name'];
          _lastAffectionBoost = affectionBoost;
          _lastHeroineDay = heroineCurrentDay;
          _lastHeroineZone = currentZone;
          _isSuccess = true;
        });
      } else {
        final errCode = response.data['error_code'];
        String msg = "선물 전송에 실패했습니다.";
        if (errCode == "NOT_ENOUGH_MONEY") {
          msg = "보유 잔액이 부족합니다.";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: const Color(0xFFE85D75)),
        );
      }
    } catch (e) {
      debugPrint("🚨 선물 보내기 에러: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("서버 통신 중 에러가 발생했습니다."), backgroundColor: Color(0xFFE85D75)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _showHeroineSelectSheet(Map<String, dynamic> gift) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '누구에게 선물할까요?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2D2420),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${gift['name']}을(를) 보냅니다. (₩${gift['price']} 소모)',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8C7B75),
                  ),
                ),
                const SizedBox(height: 24),
                _heroines.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Text('선물할 수 있는 히로인이 없습니다.', style: TextStyle(color: Colors.grey)),
                        ),
                      )
                    : SizedBox(
                        height: 110,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _heroines.length,
                          separatorBuilder: (ctx, idx) => const SizedBox(width: 18),
                          itemBuilder: (context, index) {
                            final h = _heroines[index];
                            final name = h['name'] as String;
                            final avatarImg = _getHeroineImage(name);

                            return GestureDetector(
                              onTap: () {
                                Navigator.pop(context); // 시트 닫기
                                _confirmGiftSend(name, gift);
                              },
                              child: Column(
                                children: [
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _getHeroineAvatarBg(name),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: avatarImg.isNotEmpty
                                        ? Image.asset(
                                            avatarImg,
                                            fit: BoxFit.cover,
                                            alignment: const Alignment(0, -0.4),
                                            errorBuilder: (ctx, err, stack) => Center(
                                              child: Text(
                                                name[0],
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                                              ),
                                            ),
                                          )
                                        : Center(
                                            child: Text(
                                              name[0],
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                                            ),
                                          ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2D2420),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmGiftSend(String heroineName, Map<String, dynamic> gift) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            '선물하기 확인',
            style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF2D2420)),
          ),
          content: Text(
            '$heroineName에게 ${gift['name']}을(를) 선물하시겠습니까?\n(보유 머니에서 ₩${gift['price']}이(가) 차감됩니다.)',
            style: const TextStyle(color: Color(0xFF5F4A41)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _sendGiftAction(heroineName, gift);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5F4A41),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('선물하기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isSuccess) {
      return _buildSuccessScreen();
    }

    final selectedGift = _gifts.firstWhere(
      (g) => g['id'] == _selectedGiftId,
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          '선물샵',
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
          : Stack(
              children: [
                Column(
                  children: [
                    // ── 💰 보유 잔액 카드 ──
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFE6D5C3), Color(0xFFCBB29B)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFDEC7C4).withValues(alpha: 0.25),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white30,
                              ),
                              child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '나의 보유 잔액',
                                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '₩${_money.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── 🎁 선물 목록 리스트 ──
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 90),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.76,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                        ),
                        itemCount: _gifts.length,
                        itemBuilder: (context, index) {
                          final gift = _gifts[index];
                          final id = gift['id'] as String;
                          final name = gift['name'] as String;
                          final price = gift['price'] as int;
                          final affectionBoost = gift['affection_boost'] as int;
                          final desc = gift['description'] as String;

                          final isSelected = _selectedGiftId == id;
                          final colors = _getGiftGradient(id);

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedGiftId = id;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFFCBB29B) : Colors.transparent,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isSelected
                                        ? const Color(0xFFCBB29B).withValues(alpha: 0.15)
                                        : const Color(0xFFDEC7C4).withValues(alpha: 0.08),
                                    blurRadius: isSelected ? 20 : 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 아이콘 그라데이션 원형 배경
                                  Center(
                                    child: Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        gradient: LinearGradient(
                                          colors: colors,
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      child: Icon(_getGiftIcon(id), color: Colors.white, size: 28),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF2D2420),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    desc,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF8C7B75),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const Spacer(),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '₩${price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF5F4A41),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE85D75).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '호감도 +$affectionBoost',
                                          style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFE85D75),
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
                    ),
                  ],
                ),

                // ── 🔘 하단 선물하기 버튼 ──
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.0),
                          Colors.white.withValues(alpha: 0.95),
                          Colors.white,
                        ],
                      ),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: selectedGift == null
                            ? null
                            : () => _showHeroineSelectSheet(selectedGift),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5F4A41),
                          disabledBackgroundColor: Colors.grey.shade300,
                          elevation: 0.5,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          selectedGift == null ? '선물을 선택해주세요' : '선물 보내기',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: selectedGift == null ? Colors.grey.shade600 : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── 🌀 로딩 오버레이 ──
                if (_isSending)
                  Container(
                    color: Colors.black26,
                    child: const Center(
                      child: CircularProgressIndicator(color: Color(0xFF5F4A41)),
                    ),
                  ),
              ],
            ),
    );
  }

  // ── 🎉 선물 전송 성공 화면 ──
  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // 팡파레 효과형 원형 아이콘
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE85D75).withValues(alpha: 0.1),
                ),
                child: const Center(
                  child: Icon(Icons.card_giftcard, color: Color(0xFFE85D75), size: 48),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                '선물 전송 완료!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF2D2420),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(fontSize: 15, color: Color(0xFF8C7B75), height: 1.5),
                  children: [
                    TextSpan(
                      text: _lastSentHeroine,
                      style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF5F4A41)),
                    ),
                    const TextSpan(text: '에게 '),
                    TextSpan(
                      text: _lastSentGiftName,
                      style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF5F4A41)),
                    ),
                    const TextSpan(text: '을(를) 보냈습니다.\n'),
                    const TextSpan(text: '호감도가 '),
                    TextSpan(
                      text: '+$_lastAffectionBoost',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFE85D75)),
                    ),
                    const TextSpan(text: ' 상승했습니다!'),
                  ],
                ),
              ),
              const Spacer(),
              // 버튼 영역
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onGoToChat(_lastSentHeroine, _lastHeroineDay, _lastHeroineZone);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5F4A41),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0.5,
                  ),
                  child: const Text(
                    '채팅으로 이동하기',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _isSuccess = false;
                      _selectedGiftId = null;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF5F4A41), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    '선물샵 계속 보기',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF5F4A41)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:frontend/core/api_client.dart';
import 'album_constants.dart';
import 'album_detail_screen.dart';

class AlbumHomeScreen extends StatefulWidget {
  const AlbumHomeScreen({super.key});

  @override
  State<AlbumHomeScreen> createState() => _AlbumHomeScreenState();
}

class _AlbumHomeScreenState extends State<AlbumHomeScreen> {
  bool _isLoading = true;
  Map<String, List<String>> _unlockedData = {"리안": [], "이서연": [], "코토리": []};

  @override
  void initState() {
    super.initState();
    _loadAlbumStatus();
  }

  Future<void> _loadAlbumStatus() async {
    try {
      final response = await ApiClient().dio.get('/album/status');
      if (response.data != null && response.data['status'] == 'success') {
        final data = response.data['unlocked_data'] as Map<String, dynamic>;
        setState(() {
          _unlockedData = data.map((key, value) {
            return MapEntry(key, List<String>.from(value));
          });
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("🚨 앨범 로드 실패: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: const Center(
            child: Text(
              '✕',
              style: TextStyle(
                fontSize: 22,
                color: Color(0xFF5F4A41),
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
        ),
        title: const Text(
          'ALBUM',
          style: TextStyle(
            color: Color(0xFF5F4A41),
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.0,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B76F6)),
              ),
            )
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
                children: [
                  const SizedBox(height: 10),
                  _buildHeroineCard(
                    heroineName: "리안",
                    subtitle: "Midnight Indigo",
                    gradientColors: [
                      const Color(0xFF4A148C),
                      const Color(0xFF1A237E),
                    ],
                    avatarAsset: "assets/images/character/리안/리안_실외_기본.png",
                  ),
                  const SizedBox(height: 20),
                  _buildHeroineCard(
                    heroineName: "이서연",
                    subtitle: "Soft Coral",
                    gradientColors: [
                      const Color(0xFFFF8A80),
                      const Color(0xFFFF5252),
                    ],
                    avatarAsset: "assets/images/character/이서연/이서연_기본.png",
                  ),
                  const SizedBox(height: 20),
                  _buildHeroineCard(
                    heroineName: "코토리",
                    subtitle: "Mint Emerald",
                    gradientColors: [
                      const Color(0xFF00BFA5),
                      const Color(0xFF00B0FF),
                    ],
                    avatarAsset: "assets/images/character/코토리/코토리_기본.png",
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeroineCard({
    required String heroineName,
    required String subtitle,
    required List<Color> gradientColors,
    required String avatarAsset,
  }) {
    final unlockedList = _unlockedData[heroineName] ?? [];
    final totalCount = kHeroineAlbumMetadata[heroineName]?.length ?? 0;
    final unlockedCount = unlockedList.length;
    final progress = totalCount > 0 ? (unlockedCount / totalCount) : 0.0;

    return GestureDetector(
      onTap: () {
        Navigator.of(context)
            .push(
              MaterialPageRoute(
                builder: (_) => AlbumDetailScreen(
                  heroineName: heroineName,
                  unlockedIds: unlockedList,
                  gradientColors: gradientColors,
                ),
              ),
            )
            .then((_) => _loadAlbumStatus()); // 복귀 시 데이터 새로고침
      },
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          boxShadow: [
            BoxShadow(
              color: gradientColors.last.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // 반투명 장식 원
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            // 히로인 이미지 (실루엣/크롭 형태 연출)
            Positioned(
              right: 15,
              bottom: 0,
              top: 10,
              child: Opacity(
                opacity: 0.9,
                child: Image.asset(
                  avatarAsset,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
            // 콘텐츠 정보
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subtitle.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        heroineName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "UNLOCKED",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          Text(
                            "$unlockedCount / $totalCount",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // 미려한 프로그레스 바
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          height: 6,
                          width: 160,
                          color: Colors.white.withValues(alpha: 0.2),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: progress.clamp(0.0, 1.0),
                              child: Container(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

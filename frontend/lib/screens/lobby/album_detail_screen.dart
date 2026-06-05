import 'dart:ui';
import 'package:flutter/material.dart';
import 'album_constants.dart';
import 'album_viewer_screen.dart';

class AlbumDetailScreen extends StatelessWidget {
  final String heroineName;
  final List<String> unlockedIds;
  final List<Color> gradientColors;

  const AlbumDetailScreen({
    super.key,
    required this.heroineName,
    required this.unlockedIds,
    required this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    final items = kHeroineAlbumMetadata[heroineName] ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF8F6),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: const Center(
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF5F4A41),
              size: 20,
            ),
          ),
        ),
        title: Text(
          "$heroineName의 사진첩",
          style: const TextStyle(
            color: Color(0xFF5F4A41),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: items.isEmpty
          ? const Center(
              child: Text(
                "등록된 일러스트가 없습니다.",
                style: TextStyle(color: Color(0x8C5F4A41), fontSize: 14),
              ),
            )
          : SafeArea(
              child: GridView.builder(
                padding: const EdgeInsets.all(20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.78,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isUnlocked = unlockedIds.contains(item.id);

                  return _buildIllustrationCard(context, item, isUnlocked);
                },
              ),
            ),
    );
  }

  Widget _buildIllustrationCard(
    BuildContext context,
    AlbumItem item,
    bool isUnlocked,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              if (isUnlocked) {
                Navigator.of(context).push(
                  PageRouteBuilder(
                    transitionDuration: const Duration(milliseconds: 300),
                    reverseTransitionDuration: const Duration(
                      milliseconds: 250,
                    ),
                    pageBuilder: (context, animation, secondaryAnimation) {
                      return AlbumViewerScreen(albumItem: item);
                    },
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        },
                  ),
                );
              } else {
                // 잠금 상태 피드백
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.lock_outline, color: Colors.white, size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "스토리를 진행하여 해금해 주세요.",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: const Color(0xFF6D574A),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFCEB4AC).withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (isUnlocked) ...[
                    // 해금 상태 고화질 이미지
                    Hero(
                      tag: 'illustration_${item.id}',
                      child: Image.asset(
                        item.imagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                    ),
                  ] else ...[
                    // 잠금 상태 (강력한 블러 및 어두운 필터 효과)
                    ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Image.asset(
                        item.imagePath,
                        fit: BoxFit.cover,
                        color: Colors.black.withValues(alpha: 0.3),
                        colorBlendMode: BlendMode.darken,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(color: const Color(0xFFE8E2DE));
                        },
                      ),
                    ),
                    // 자물쇠 아이콘
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.5),
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // 하단 타이틀 렌더링
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isUnlocked ? item.title : "???",
                style: const TextStyle(
                  color: Color(0xFF5F4A41),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (isUnlocked) ...[
                const SizedBox(height: 2),
                Text(
                  "Day ${item.unlockDay} ${item.unlockZone}",
                  style: const TextStyle(
                    color: Color(0xFF8B76F6),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'album_constants.dart';

class AlbumViewerScreen extends StatefulWidget {
  final AlbumItem albumItem;

  const AlbumViewerScreen({
    super.key,
    required this.albumItem,
  });

  @override
  State<AlbumViewerScreen> createState() => _AlbumViewerScreenState();
}

class _AlbumViewerScreenState extends State<AlbumViewerScreen> {
  bool _showUI = true;
  Timer? _uiTimer;
  final TransformationController _transformationController = TransformationController();

  @override
  void initState() {
    super.initState();
    _startUITimer();
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _transformationController.dispose();
    super.dispose();
  }

  void _startUITimer() {
    _uiTimer?.cancel();
    _uiTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showUI = false);
      }
    });
  }

  void _toggleUI() {
    setState(() {
      _showUI = !_showUI;
    });
    if (_showUI) {
      _startUITimer();
    } else {
      _uiTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 고화질 이미지 감상 영역 (Pinch-to-zoom 지원) ──
          GestureDetector(
            onTap: _toggleUI,
            child: Center(
              child: InteractiveViewer(
                transformationController: _transformationController,
                minScale: 1.0,
                maxScale: 4.0,
                onInteractionStart: (_) {
                  // 유저가 조작하는 동안은 UI 타이머 정지 및 숨김
                  _uiTimer?.cancel();
                  if (_showUI) {
                    setState(() => _showUI = false);
                  }
                },
                onInteractionEnd: (_) {
                  // 조작이 끝나면 줌 수치가 1.0에 가까우면 다시 타이머 활성화 가능
                  if (_transformationController.value.getMaxScaleOnAxis() <= 1.0) {
                    setState(() => _showUI = true);
                    _startUITimer();
                  }
                },
                child: Hero(
                  tag: 'illustration_${widget.albumItem.id}',
                  child: Image.asset(
                    widget.albumItem.imagePath,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Text(
                          "이미지를 로드할 수 없습니다.",
                          style: TextStyle(color: Colors.white),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          // ── 상단 닫기 버튼 오버레이 ──
          AnimatedOpacity(
            opacity: _showUI ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: IgnorePointer(
              ignoring: !_showUI,
              child: SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 15, right: 20),
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.4),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── 하단 감성 대사 오버레이 (Glassmorphism 패널) ──
          AnimatedOpacity(
            opacity: _showUI ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: IgnorePointer(
              ignoring: !_showUI,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    MediaQuery.of(context).padding.bottom > 0
                        ? MediaQuery.of(context).padding.bottom + 8
                        : 20,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: Colors.black.withValues(alpha: 0.55),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 일러스트 에피소드 조건 태그
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: Colors.white.withValues(alpha: 0.15),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                "Day ${widget.albumItem.unlockDay} ${widget.albumItem.unlockZone}",
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            // 제목
                            Text(
                              widget.albumItem.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            // 설명 / 대사
                            Text(
                              widget.albumItem.description,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 13.5,
                                height: 1.45,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

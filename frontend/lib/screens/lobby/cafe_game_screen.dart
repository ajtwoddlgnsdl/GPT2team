import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/api_client.dart';

class CafeGameScreen extends StatefulWidget {
  final int actionPoints;
  final int money;
  final int day;
  final VoidCallback onClose;
  final VoidCallback? onPhoneRequested;
  final VoidCallback? onTutorialCompleted;
  final Function(int earnedMoney)? onRewardEarned;
  final Function(int newAP)? onAPChanged;
  final String assetPath;
  final bool isTutorial;

  const CafeGameScreen({
    super.key,
    required this.actionPoints,
    required this.money,
    required this.day,
    required this.onClose,
    this.onPhoneRequested,
    this.onTutorialCompleted,
    this.onRewardEarned,
    this.onAPChanged,
    this.assetPath = 'assets/html/cafe_game/index.html',
    this.isTutorial = false,
  });

  @override
  State<CafeGameScreen> createState() => _CafeGameScreenState();
}

class _CafeGameScreenState extends State<CafeGameScreen> {
  final WebViewController _controller = WebViewController();
  final ApiClient _api = ApiClient();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    _initWebView();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  Future<void> _initWebView() async {
    try {
      _setupWebView();
    } catch (e) {
      debugPrint('카페 미니게임 로드 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('미니게임을 불러오지 못했습니다.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        _closeCafeGame();
      }
    }
  }

  void _setupWebView() {
    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          _controller.runJavaScript('''
            if (typeof GPT2TeamCafeGame !== 'undefined' && GPT2TeamCafeGame.configure) {
              GPT2TeamCafeGame.configure({
                day: ${widget.day},
                ap: ${widget.actionPoints},
                money: ${widget.money},
                canPlay: ${widget.isTutorial || widget.actionPoints > 0}
              });
            }
          ''');
          if (mounted) setState(() => _isLoading = false);
        },
        onWebResourceError: (error) {
          debugPrint('WebView 리소스 에러: ${error.description}');
        },
      ))
      ..addJavaScriptChannel(
        'KotoriCafeBridge',
        onMessageReceived: (message) {
          _handleBridgeMessage(message.message);
        },
      )
      ..loadFlutterAsset(widget.assetPath);
  }

  void _handleBridgeMessage(String rawMessage) {
    try {
      final data = jsonDecode(rawMessage);
      final type = data['type'] as String?;
      final payload = data['payload'] as Map<String, dynamic>? ?? {};

      switch (type) {
        case 'start_requested':
          final requestId = payload['_requestId'] as int?;
          if (requestId != null) _handleStartRequest(requestId);
          break;
        case 'reward_requested':
          final requestId = payload['_requestId'] as int?;
          if (requestId != null) _handleRewardRequest(requestId, payload);
          break;
        case 'story_requested':
          _closeCafeGame();
          break;
        case 'phone_requested':
          if (widget.isTutorial) {
            _returnToLobbyFromTutorial();
            break;
          }
          _openPhoneFromCafe();
          break;
        case 'phone_app_requested':
          if (widget.isTutorial) {
            _returnToLobbyFromTutorial();
            break;
          }
          _openPhoneFromCafe();
          break;
        case 'tutorial_completed':
          _completeCafeTutorial();
          break;
        case 'tutorial_exit_to_lobby':
          _returnToLobbyFromTutorial();
          break;
      }
    } catch (_) {}
  }

  Future<void> _handleStartRequest(int requestId) async {
    try {
      final res = await _api.dio.post(
        '/minigame/start',
        data: {'game_type': 'cafe_kotori'},
      );
      final data = res.data as Map<String, dynamic>;
      final jsonStr = jsonEncode(data).replaceAll('\\', '\\\\').replaceAll("'", "\\'");
      _controller.runJavaScript(
        "GPT2TeamCafeGame.resolveRequest($requestId, JSON.parse('$jsonStr'));",
      );
      if (data['status'] == 'success' && data.containsKey('current_ap')) {
        widget.onAPChanged?.call(data['current_ap'] as int);
      }
    } catch (e) {
      _controller.runJavaScript(
        "GPT2TeamCafeGame.rejectRequest($requestId, '행동력을 차감할 수 없습니다.');",
      );
      debugPrint('minigame/start 에러: $e');
    }
  }

  Future<void> _handleRewardRequest(int requestId, Map<String, dynamic> payload) async {
    try {
      final res = await _api.dio.post(
        '/minigame/reward',
        data: {
          'game_type': 'cafe_kotori',
          'result': payload['result'],
          'latte_art': payload['latte_art'] ?? false,
        },
      );
      final data = res.data as Map<String, dynamic>;
      final jsonStr = jsonEncode(data).replaceAll('\\', '\\\\').replaceAll("'", "\\'");
      _controller.runJavaScript(
        "GPT2TeamCafeGame.resolveRequest($requestId, JSON.parse('$jsonStr'));",
      );
      if (data.containsKey('earned_money')) {
        widget.onRewardEarned?.call(data['earned_money'] as int);
      }
      if (data.containsKey('current_ap')) {
        widget.onAPChanged?.call(data['current_ap'] as int);
      }
    } catch (e) {
      _controller.runJavaScript(
        "GPT2TeamCafeGame.rejectRequest($requestId, '보상 동기화 실패');",
      );
      debugPrint('minigame/reward 에러: $e');
    }
  }

  void _openPhoneFromCafe() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]).then((_) {
      if (widget.onPhoneRequested != null) {
        widget.onPhoneRequested!.call();
      } else {
        widget.onClose();
      }
    });
  }

  void _closeCafeGame() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]).then((_) {
      widget.onClose();
    });
  }

  void _completeCafeTutorial() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]).then((_) {
      if (widget.onTutorialCompleted != null) {
        widget.onTutorialCompleted!.call();
      } else {
        widget.onClose();
      }
    });
  }

  void _returnToLobbyFromTutorial() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]).then((_) {
      if (widget.onPhoneRequested != null) {
        widget.onPhoneRequested!.call();
      } else {
        widget.onClose();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _closeCafeGame();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF2F271F),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            Positioned(
              top: 8,
              left: 8,
              child: SafeArea(
                child: IconButton(
                  onPressed: _closeCafeGame,
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white70,
                    size: 28,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

class CafeGameScreen extends StatefulWidget {
  final int actionPoints;
  final int money;
  final int day;
  final VoidCallback onClose;
  final VoidCallback? onPhoneRequested;
  final Function(int earnedMoney)? onRewardEarned;
  final Function(int newAP)? onAPChanged;

  const CafeGameScreen({
    super.key,
    required this.actionPoints,
    required this.money,
    required this.day,
    required this.onClose,
    this.onPhoneRequested,
    this.onRewardEarned,
    this.onAPChanged,
  });

  @override
  State<CafeGameScreen> createState() => _CafeGameScreenState();
}

class _CafeGameScreenState extends State<CafeGameScreen> {
  final WebViewController _controller = WebViewController();
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
      debugPrint('🚨 카페 미니게임 로드 실패: $e');
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
            if (typeof GPT2TeamCafeGame !== 'undefined' && GPT2TeamCafeGame.setState) {
              GPT2TeamCafeGame.setState({
                day: ${widget.day},
                ap: ${widget.actionPoints},
                money: ${widget.money},
                storyCompleted: true,
                canPlay: true
              });
            }
          ''');
          if (mounted) setState(() => _isLoading = false);
        },
        onWebResourceError: (error) {
          debugPrint('🚨 WebView 리소스 에러: ${error.description}');
        },
      ))
      ..addJavaScriptChannel(
        'KotoriCafeBridge',
        onMessageReceived: (message) {
          _handleBridgeMessage(message.message);
        },
      )
      ..loadFlutterAsset('assets/html/cafe_game/index.html');
  }

  void _handleBridgeMessage(String rawMessage) {
    try {
      final data = jsonDecode(rawMessage);
      final type = data['type'] as String?;
      final payload = data['payload'] as Map<String, dynamic>? ?? {};

      switch (type) {
        case 'reward':
          final earned = payload['earned_money'] as int? ?? 0;
          widget.onRewardEarned?.call(earned);
          break;
        case 'status':
          if (payload.containsKey('current_ap')) {
            widget.onAPChanged?.call(payload['current_ap'] as int);
          }
          break;
        case 'story_requested':
          _closeCafeGame();
          break;
        case 'phone_requested':
          _openPhoneFromCafe();
          break;
        case 'phone_app_requested':
          _openPhoneFromCafe();
          break;
      }
    } catch (_) {}
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

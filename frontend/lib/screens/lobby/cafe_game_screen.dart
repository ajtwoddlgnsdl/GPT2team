import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

class CafeGameScreen extends StatefulWidget {
  final int actionPoints;
  final int money;
  final int day;
  final VoidCallback onClose;
  final Function(int earnedMoney)? onRewardEarned;
  final Function(int newAP)? onAPChanged;

  const CafeGameScreen({
    super.key,
    required this.actionPoints,
    required this.money,
    required this.day,
    required this.onClose,
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
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
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

  Future<String> _assetToDataUri(String assetPath, String mimeType) async {
    final data = await rootBundle.load(assetPath);
    final b64 = base64Encode(data.buffer.asUint8List());
    return 'data:$mimeType;base64,$b64';
  }

  Future<void> _initWebView() async {
    const basePath = 'assets/html/cafe_game';

    // Load HTML source
    String html = await rootBundle.loadString('$basePath/index.html');

    // Load font and images in parallel
    final customerNames = [
      'barista', 'beanie-boy', 'child', 'complainer', 'couple',
      'dark-flame', 'grandma', 'gym-bro', 'office-worker', 'poet',
      'sns-girl', 'student',
    ];

    final futures = <Future<String>>[
      _assetToDataUri('$basePath/YOnepick-Bold.ttf', 'font/ttf'),
      _assetToDataUri('$basePath/cafe_main.png', 'image/png'),
      _assetToDataUri('$basePath/cafe제조대.png', 'image/png'),
      ...customerNames.map(
        (name) => _assetToDataUri('$basePath/customers/$name.png', 'image/png'),
      ),
    ];

    final dataUris = await Future.wait(futures);

    // Replace font reference
    html = html.replaceAll(
      'url("YOnepick-Bold.ttf")',
      'url("${dataUris[0]}")',
    );

    // Replace background image references
    html = html.replaceAll('url("cafe_main.png")', 'url("${dataUris[1]}")');
    html = html.replaceAll('url("cafe제조대.png")', 'url("${dataUris[2]}")');

    // Replace customer image references
    for (var i = 0; i < customerNames.length; i++) {
      html = html.replaceAll(
        'customers/${customerNames[i]}.png',
        dataUris[3 + i],
      );
    }

    // Inject initial state (day/ap/money) into HTML before init() runs.
    // Bridge stays disabled — loadHtmlString uses about:blank origin,
    // so fetch() to the backend API would fail with CORS/network errors.
    // The game runs in standalone mode, managing state locally.
    final stateScript = '''
<script>
  window.GPT2TEAM_CAFE_CONFIG = {
    day: ${widget.day},
    ap: ${widget.actionPoints},
    money: ${widget.money},
    storyCompleted: true,
    canPlay: true
  };
</script>
''';
    html = html.replaceFirst('</head>', '$stateScript</head>');

    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _isLoading = false);
        },
      ))
      ..addJavaScriptChannel(
        'KotoriCafeBridge',
        onMessageReceived: (message) {
          _handleBridgeMessage(message.message);
        },
      )
      ..loadHtmlString(html);
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
      }
    } catch (_) {}
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

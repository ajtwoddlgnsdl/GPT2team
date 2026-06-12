import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import '../../core/api_client.dart';
import '../lobby/lobby_screen.dart';


class StoryScreen extends StatefulWidget {
  final String storyId;
  final String storyTicket;
  final String? heroineName;

  const StoryScreen({
    super.key,
    required this.storyId,
    required this.storyTicket,
    this.heroineName,
  });

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  List<dynamic> _scriptLines = [];
  int _currentIndex = 0;
  bool _isLoading = true;

  String _playerName = "주인공";
  final TextEditingController _nameController = TextEditingController();

  // 💡 비주얼 및 선택지 관련 상태 변수 추가
  String? _currentBgImage;
  String? _currentCharacterImage;
  int _earnedBonusScore = 0;
  bool _isChoiceMode = false;
  List<dynamic> _currentChoices = [];

  @override
  void initState() {
    super.initState();
    _loadPlayerName();
    _loadStoryScript();
  }

  Future<void> _loadPlayerName() async {
    final name = await ApiClient().storage.read(key: 'username');
    if (name != null) {
      setState(() {
        _playerName = name;
      });
    }
  }

  // 대본 JSON 파일 불러오기
  Future<void> _loadStoryScript() async {
    String filePath = ''; // 에러 발생 시 경로를 출력하기 위해 밖으로 뺌
    try {
      // 💡 스토리 ID의 접두사에 따라 폴더 경로를 자동으로 분류합니다.
      String folder = 'intro2'; // day... 등 공략 전 스토리
      if (widget.storyId.startsWith('intro_')) {
        folder = 'intro1'; // 프롤로그 및 튜토리얼
      } else if (widget.storyId.startsWith('MAIN_')) {
        folder = 'main';
      } else if (widget.storyId.startsWith('ENDING_')) {
        folder = 'ending';
      }

      filePath = 'assets/scripts/$folder/${widget.storyId}.json';
      if (folder != 'intro1' && widget.heroineName != null) {
        filePath =
            'assets/scripts/$folder/${widget.heroineName}/${widget.storyId}.json';
      }

      final String jsonString = await rootBundle.loadString(filePath);
      setState(() {
        _scriptLines = jsonDecode(jsonString);
        if (_scriptLines.isNotEmpty) {
          _updateVisuals(_scriptLines[0]);
        }
        _isLoading = false;
      });
      _precacheScriptImages();
    } catch (e) {
      debugPrint("🚨 대본 로드 실패 ($filePath): $e");
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LobbyScreen()),
        );
      }
    }
  }

  void _precacheScriptImages() {
    final Set<String> paths = {};
    for (final line in _scriptLines) {
      if (line is Map<String, dynamic>) {
        if (line.containsKey('bg_image')) paths.add(line['bg_image']);
        if (line['character_image'] != null) paths.add(line['character_image']);
      }
    }
    for (final path in paths) {
      precacheImage(AssetImage(path), context);
    }
  }

  // 배경과 캐릭터 이미지를 업데이트하는 함수
  void _updateVisuals(Map<String, dynamic> line) {
    if (line.containsKey('bg_image')) {
      _currentBgImage = line['bg_image'];
    }
    if (line.containsKey('character_image')) {
      _currentCharacterImage = line['character_image'] as String?;
    }
  }

  // 💡 화면을 터치했을 때 다음 스토리로 넘어가는 핵심 로직!
  void _nextStory() {
    if (_isChoiceMode || _isLoading) return;

    final currentLine = _scriptLines[_currentIndex] as Map<String, dynamic>;

    // 1. 현재 대본에 '닉네임 입력' 액션이 있다면? -> 대사 진행을 멈추고 팝업 띄움!
    if (currentLine.containsKey('action')) {
      if (currentLine['action'] == 'input_nickname') {
        _showNameInputDialog();
        return;
      } else if (currentLine['action'] == 'choice') {
        // 💡 선택지 액션 발동!
        setState(() {
          _isChoiceMode = true;
          _currentChoices = currentLine['choices'];
        });
        return;
      }
    }

    // 2. 평범한 대사라면 다음 줄로 이동
    _advanceLine();
  }

  void _advanceLine() {
    if (_currentIndex < _scriptLines.length - 1) {
      setState(() {
        _currentIndex++;
        _updateVisuals(_scriptLines[_currentIndex]);
      });
    } else {
      // 3. 파일 전체를 다 읽었다면 클리어 API 쏘기!
      _completeStory();
    }
  }

  // 유저가 선택지를 눌렀을 때의 처리
  void _onChoiceSelected(Map<String, dynamic> choice) {
    // 1. 보너스 점수가 있다면 저장해두기
    if (choice.containsKey('bonus_score')) {
      _earnedBonusScore = choice['bonus_score'];
    }

    // 2. 선택지에 딸린 다음 대사(next_lines)가 있다면 현재 스크립트 중간에 끼워넣기!
    if (choice.containsKey('next_lines')) {
      List<dynamic> nextLines = choice['next_lines'];
      _scriptLines.insertAll(_currentIndex + 1, nextLines);
    }

    setState(() => _isChoiceMode = false);
    _advanceLine(); // 자연스럽게 다음(혹은 끼워넣은) 대사로 이동
  }

  Future<void> _completeStory() async {
    setState(() {
      _isLoading = true;
    });

    final requestData = {
      "story_ticket": widget.storyTicket,
      "bonus_score": _earnedBonusScore,
    };

    try {
      final response = await ApiClient().dio.post(
        '/complete-story',
        data: requestData,
      );

      if (response.statusCode == 200) {
        if (response.data['status'] == 'success') {
          debugPrint("🎉 스토리 클리어 완료! DB 업데이트 성공!");

          if (!mounted) return;

          final nextStory = response.data['next_story'];
          if (nextStory != null) {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (_, _, _) => StoryScreen(
                  storyId: nextStory['story_id'],
                  storyTicket: nextStory['story_ticket'],
                  heroineName: nextStory['heroine_name'],
                ),
                transitionDuration: const Duration(milliseconds: 800),
                reverseTransitionDuration: const Duration(milliseconds: 400),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeInOut,
                    ),
                    child: child,
                  );
                },
              ),
            );
          } else {
            final unlockedId = response.data['unlocked_id'];
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => LobbyScreen(
                  unlockedIllustrationId: unlockedId,
                ),
              ),
            );
          }
        } else if (response.data['status'] == 'error') {
          if (!mounted) return;
          final errorCode = response.data['error_code'] ?? 'UNKNOWN_ERROR';
          debugPrint("🚨 스토리 클리어 실패: $errorCode");

          String errorMessage = '스토리 완료 처리 중 문제가 발생했습니다.';
          if (errorCode == 'STORY_TICKET_EXPIRED') {
            errorMessage = '스토리 진행 시간이 초과되어 티켓이 만료되었습니다.';
          } else if (errorCode == 'ALREADY_CLEARED_TODAY' ||
              errorCode == 'ALREADY_CLEARED_ZONE') {
            errorMessage = '이미 클리어한 스토리입니다.';
          } else if (errorCode == 'INVALID_STORY_TICKET' ||
              errorCode == 'INVALID_DAY_TICKET') {
            errorMessage = '잘못된 스토리 접근입니다.';
          } else if (errorCode == 'INVALID_BONUS_TOKEN') {
            errorMessage = '보너스 토큰 검증에 실패했습니다.';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.redAccent,
            ),
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LobbyScreen()),
          );
        }
      }
    } on DioException catch (e) {
      debugPrint("🚨 스토리 클리어 에러: ${e.response?.data ?? e.message}");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('통신 에러가 발생했습니다. 로비로 이동합니다.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LobbyScreen()),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showNameInputDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            '이름을 기억해 내자',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white),
            maxLength: 12,
            decoration: const InputDecoration(
              hintText: '2~12자로 입력해주세요',
              hintStyle: TextStyle(color: Colors.grey),
              counterStyle: TextStyle(color: Colors.grey),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                final trimmed = _nameController.text.trim();
                if (trimmed.length < 2) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('이름은 2자 이상 입력해주세요!'),
                      backgroundColor: Colors.redAccent,
                      duration: Duration(seconds: 2),
                    ),
                  );
                  return;
                }
                Navigator.pop(context);
                _updateNicknameAndContinue();
              },
              child: const Text('확인', style: TextStyle(color: Colors.blue)),
            ),
          ],
        );
      },
    );
  }

  // 💡 닉네임을 서버에 저장하고, 스무스하게 다음 대사로 이어가는 함수
  Future<void> _updateNicknameAndContinue() async {
    final username = _nameController.text.trim();
    if (username.length < 2) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. 이름 업데이트 API 쏘기
      await ApiClient().dio.post(
        '/update-nickname',
        data: {"username": username},
      );
      debugPrint("✅ 닉네임 설정 성공!");

      // 2. 금고에 이름 저장
      await ApiClient().storage.write(key: 'username', value: username);

      // 3. 통신이 완료되었으니, 화면에 이름 적용하고 곧바로 다음 줄 대사 띄우기!
      setState(() {
        _playerName = username;
        _isLoading = false;
      });
      _advanceLine(); // 여기서 자연스럽게 다음 대사로 넘어감!
    } on DioException catch (e) {
      debugPrint("🚨 닉네임 설정 에러: ${e.response?.data ?? e.message}");
      setState(() {
        _isLoading = false;
      });

      if (!mounted) return;

      final statusCode = e.response?.statusCode;
      String errorMsg;
      if (statusCode == 401 || statusCode == 403) {
        errorMsg = '로그인 세션이 만료되었습니다. 다시 시작해주세요.';
      } else if (statusCode == 422) {
        errorMsg = '닉네임은 2자~12자 사이로 입력해주세요!';
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        errorMsg = '서버 연결에 실패했습니다. 잠시 후 다시 시도해주세요.';
      } else {
        errorMsg = '오류가 발생했습니다. 다시 시도해주세요.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.redAccent,
        ),
      );
      _showNameInputDialog();
    }
  }

  // 긴 대사를 문장부호 뒤에서 자동 줄바꿈
  String _formatLongText(String text) {
    if (text.length <= 25) return text;
    // 이미 줄바꿈이 있으면 그대로
    if (text.contains('\n')) return text;
    // 문장부호 뒤 공백 위치에서 줄바꿈 삽입
    final buffer = StringBuffer();
    int lineLen = 0;
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      lineLen++;
      if (lineLen >= 20) {
        // 문장부호 + 공백 조합이면 줄바꿈
        final c = text[i];
        final isBreakChar = '.!?~…, 。'.contains(c);
        final nextIsSpace = i + 1 < text.length && text[i + 1] == ' ';
        if (isBreakChar && nextIsSpace) {
          buffer.write('\n');
          i++; // 공백 스킵
          lineLen = 0;
          continue;
        }
        // 공백이면 줄바꿈
        if (c == ' ') {
          buffer.write('\n');
          lineLen = 0;
          continue;
        }
      }
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    // 💡 대본을 찾지 못한 경우 에러 없이 빈 검은 화면을 띄워 앱 멈춤 방지
    if (_scriptLines.isEmpty) {
      return const Scaffold(backgroundColor: Colors.black);
    }

    final currentLine = _scriptLines[_currentIndex] as Map<String, dynamic>;

    // 💡 마법 발생! JSON에 {name}이라고 적힌 부분을 진짜 유저 이름으로 바꿔치기!
    String speakerRaw = currentLine['speaker'] ?? "";
    String textRaw = currentLine['text'] ?? "";

    String displaySpeaker = speakerRaw.replaceAll('{name}', _playerName);
    String displayText = _formatLongText(textRaw.replaceAll('{name}', _playerName));

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _nextStory,
        child: Stack(
          children: [
            // 1. 🌅 배경 이미지 렌더링
            if (_currentBgImage != null)
              Positioned.fill(
                child: Image.asset(
                  _currentBgImage!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint("🚨 배경 이미지 로드 실패: $_currentBgImage");
                    return Container(color: Colors.black);
                  },
                ),
              )
            else
              Container(color: Colors.black),

            // 2. 🧍‍♀️ 캐릭터 스탠딩 이미지 렌더링 (character_image 있는 라인에서만 표시)
            if (_currentCharacterImage != null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: MediaQuery.of(context).size.height * 0.58,
                child: Center(
                  child: Image.asset(
                    _currentCharacterImage!,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    alignment: Alignment.bottomCenter,
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint("🚨 캐릭터 이미지 로드 실패: $_currentCharacterImage");
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),

            // 3. 💬 대화창 렌더링
            Positioned(
              bottom: 50,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (displaySpeaker.isNotEmpty) ...[
                      Text(
                        displaySpeaker,
                        style: const TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      displayText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 4. 🎯 선택지 오버레이 렌더링
            if (_isChoiceMode)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.5),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _currentChoices.map((choice) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 10,
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.95,
                            ),
                            foregroundColor: Colors.black,
                            minimumSize: const Size(double.infinity, 55),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          onPressed: () => _onChoiceSelected(choice),
                          child: Text(
                            (choice['text'] ?? '').replaceAll(
                              '{name}',
                              _playerName,
                            ),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

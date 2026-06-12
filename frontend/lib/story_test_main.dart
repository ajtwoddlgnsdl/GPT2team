import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StoryTestApp());
}

class StoryTestApp extends StatelessWidget {
  const StoryTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Story Test Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff8b5cf6),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xff0b0b10),
        fontFamily: 'YChoiAe',
      ),
      home: const StoryTestScreen(),
    );
  }
}

class StoryOption {
  const StoryOption(this.label, this.path);

  final String label;
  final String path;
}

class StoryTestScreen extends StatefulWidget {
  const StoryTestScreen({super.key});

  @override
  State<StoryTestScreen> createState() => _StoryTestScreenState();
}

class _StoryTestScreenState extends State<StoryTestScreen> {
  final _nameController = TextEditingController(text: '플레이어');
  final _jumpController = TextEditingController();

  List<StoryOption> _stories = [];
  StoryOption? _selectedStory;
  List<Map<String, dynamic>> _lines = [];
  int _index = 0;
  int _score = 0;
  String? _backgroundImage;
  String? _characterImage;
  bool _loading = true;
  String? _error;
  bool _showChoices = false;
  List<Map<String, dynamic>> _choices = [];
  final List<_StorySnapshot> _history = [];

  @override
  void initState() {
    super.initState();
    _loadStoryCatalog();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _jumpController.dispose();
    super.dispose();
  }

  Future<void> _loadStoryCatalog() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final paths =
          manifest
              .listAssets()
              .where(
                (path) =>
                    path.endsWith('.json') &&
                    (path.startsWith('assets/scripts/intro1/') ||
                        path.startsWith('assets/scripts/intro2/') ||
                        path.startsWith('assets/scripts/main/')),
              )
              .toList()
            ..sort((a, b) => _storySortKey(a).compareTo(_storySortKey(b)));

      if (paths.isEmpty) {
        throw const FormatException('테스트할 스토리 JSON을 찾지 못했습니다.');
      }

      final stories = paths
          .map((path) => StoryOption(_storyLabel(path), path))
          .toList();
      final initialStory = stories.firstWhere(
        (story) => story.path.endsWith('intro_3_prologue.json'),
        orElse: () => stories.first,
      );

      setState(() {
        _stories = stories;
        _selectedStory = initialStory;
      });
      await _loadStory();
    } catch (error) {
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  String _storyLabel(String path) {
    final parts = path.split('/');
    final section = parts[2].toUpperCase();
    final fileName = parts.last.replaceAll('.json', '').replaceAll('_', ' ');
    if (parts[2] == 'intro1') {
      return '$section · $fileName';
    }
    return '$section · ${parts[3]} · $fileName';
  }

  String _storySortKey(String path) {
    final parts = path.split('/');
    final sectionOrder = switch (parts[2]) {
      'intro1' => 0,
      'intro2' => 1,
      'main' => 2,
      _ => 9,
    };
    final heroine = parts.length > 4 ? parts[3] : '';
    final day =
        int.tryParse(
          RegExp(r'day(\d+)').firstMatch(parts.last)?.group(1) ?? '',
        ) ??
        0;
    return '$sectionOrder|$heroine|${day.toString().padLeft(3, '0')}|$path';
  }

  Future<void> _loadStory() async {
    final selectedStory = _selectedStory;
    if (selectedStory == null) return;

    setState(() {
      _loading = true;
      _error = null;
      _showChoices = false;
      _choices = [];
      _history.clear();
    });

    try {
      final jsonString = await rootBundle.loadString(selectedStory.path);
      final decoded = jsonDecode(jsonString);
      if (decoded is! List) {
        throw const FormatException('JSON 최상위 값이 배열이 아닙니다.');
      }

      final lines = decoded
          .map((line) => Map<String, dynamic>.from(line as Map))
          .toList();

      setState(() {
        _lines = lines;
        _index = 0;
        _score = 0;
        _backgroundImage = null;
        _characterImage = null;
        _loading = false;
        if (_lines.isNotEmpty) {
          _applyVisuals(_lines.first);
        }
      });
    } catch (error) {
      setState(() {
        _lines = [];
        _loading = false;
        _error = error.toString();
      });
    }
  }

  void _applyVisuals(Map<String, dynamic> line) {
    if (line.containsKey('bg_image')) {
      _backgroundImage = line['bg_image'] as String?;
    }
    if (line.containsKey('character_image')) {
      _characterImage = line['character_image'] as String?;
    }
  }

  void _saveSnapshot() {
    _history.add(
      _StorySnapshot(
        lines: _lines.map((line) => Map<String, dynamic>.from(line)).toList(),
        index: _index,
        score: _score,
        backgroundImage: _backgroundImage,
        characterImage: _characterImage,
        showChoices: _showChoices,
        choices: _choices
            .map((choice) => Map<String, dynamic>.from(choice))
            .toList(),
      ),
    );
  }

  void _next() {
    if (_loading || _lines.isEmpty || _showChoices) return;

    final line = _lines[_index];
    final rawChoices = line['choices'];
    if (rawChoices is List) {
      _saveSnapshot();
      setState(() {
        _showChoices = true;
        _choices = rawChoices
            .map((choice) => Map<String, dynamic>.from(choice as Map))
            .toList();
      });
      return;
    }

    if (_index >= _lines.length - 1) {
      _showFinishedDialog();
      return;
    }

    _saveSnapshot();
    setState(() {
      _index++;
      _applyVisuals(_lines[_index]);
    });
  }

  void _previous() {
    if (_history.isEmpty) return;
    final snapshot = _history.removeLast();

    setState(() {
      _lines = snapshot.lines;
      _index = snapshot.index;
      _score = snapshot.score;
      _backgroundImage = snapshot.backgroundImage;
      _characterImage = snapshot.characterImage;
      _showChoices = snapshot.showChoices;
      _choices = snapshot.choices;
    });
  }

  void _selectChoice(Map<String, dynamic> choice) {
    _saveSnapshot();

    final bonus = choice['bonus_score'];
    final nextLines = choice['next_lines'];

    setState(() {
      if (bonus is num) {
        _score += bonus.toInt();
      }
      if (nextLines is List) {
        _lines.insertAll(
          _index + 1,
          nextLines.map((line) => Map<String, dynamic>.from(line as Map)),
        );
      }
      _showChoices = false;
      _choices = [];

      if (_index < _lines.length - 1) {
        _index++;
        _applyVisuals(_lines[_index]);
      }
    });
  }

  void _jumpToLine() {
    final target = int.tryParse(_jumpController.text.trim());
    if (target == null || target < 1 || target > _lines.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('1부터 ${_lines.length} 사이를 입력하세요.')),
      );
      return;
    }

    _saveSnapshot();
    String? background;
    String? character;
    for (var i = 0; i < target; i++) {
      final line = _lines[i];
      if (line.containsKey('bg_image')) {
        background = line['bg_image'] as String?;
      }
      if (line.containsKey('character_image')) {
        character = line['character_image'] as String?;
      }
    }

    setState(() {
      _index = target - 1;
      _backgroundImage = background;
      _characterImage = character;
      _showChoices = false;
      _choices = [];
    });
  }

  Future<void> _showFinishedDialog() {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('스토리 종료'),
        content: Text('마지막 대사입니다.\n누적 선택지 점수: $_score'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _loadStory();
            },
            child: const Text('처음부터'),
          ),
        ],
      ),
    );
  }

  String _replaceName(Object? value) {
    return (value?.toString() ?? '').replaceAll(
      '{name}',
      _nameController.text.trim().isEmpty
          ? '플레이어'
          : _nameController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 900;
            final controls = _buildControls(compact);
            final player = _buildPlayer();

            if (compact) {
              return Column(
                children: [
                  controls,
                  Expanded(child: player),
                ],
              );
            }

            return Row(
              children: [
                SizedBox(width: 310, child: controls),
                Expanded(child: player),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildControls(bool compact) {
    final content = Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'STORY LAB',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '웹 대본 테스트 플레이어',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<StoryOption>(
            initialValue: _selectedStory,
            decoration: const InputDecoration(
              labelText: '스토리',
              border: OutlineInputBorder(),
            ),
            items: _stories
                .map(
                  (story) =>
                      DropdownMenuItem(value: story, child: Text(story.label)),
                )
                .toList(),
            onChanged: (story) {
              if (story == null) return;
              setState(() => _selectedStory = story);
              _loadStory();
            },
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '플레이어 이름',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          if (_lines.isNotEmpty) ...[
            LinearProgressIndicator(
              value: (_index + 1) / _lines.length,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 8),
            Text(
              '${_index + 1} / ${_lines.length}   선택지 점수 $_score',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _history.isEmpty ? null : _previous,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('이전'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _loading || _showChoices ? null : _next,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('다음'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _loading ? null : _loadStory,
            icon: const Icon(Icons.restart_alt),
            label: const Text('처음부터'),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _jumpController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '대사 번호',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _jumpToLine(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: '해당 대사로 이동',
                onPressed: _lines.isEmpty ? null : _jumpToLine,
                icon: const Icon(Icons.subdirectory_arrow_right),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '화면 클릭 또는 Space: 다음\nBackspace: 이전',
            style: TextStyle(
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );

    return Material(
      color: const Color(0xff15151d),
      child: compact
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(width: 760, child: content),
            )
          : SingleChildScrollView(child: content),
    );
  }

  Widget _buildPlayer() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('대본을 불러오지 못했습니다.\n$_error', textAlign: TextAlign.center),
        ),
      );
    }
    if (_lines.isEmpty) {
      return const Center(child: Text('대사가 없습니다.'));
    }

    final line = _lines[_index];
    final speaker = _replaceName(line['speaker']);
    final text = _replaceName(line['text']);

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.space) {
          _next();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.backspace) {
          _previous();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: GestureDetector(
                onTap: _next,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_backgroundImage != null)
                          Image.asset(
                            _backgroundImage!,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            errorBuilder: (_, _, _) =>
                                const ColoredBox(color: Colors.black),
                          ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.15),
                                Colors.black.withValues(alpha: 0.72),
                              ],
                              stops: const [0, 0.55, 1],
                            ),
                          ),
                        ),
                        if (_characterImage != null)
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: 0.82,
                              child: Image.asset(
                                _characterImage!,
                                fit: BoxFit.contain,
                                alignment: Alignment.bottomCenter,
                                gaplessPlayback: true,
                                errorBuilder: (_, _, _) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        Positioned(
                          top: 16,
                          right: 16,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              child: Text(
                                '#${_index + 1}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 20,
                          right: 20,
                          bottom: 24,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
                            decoration: BoxDecoration(
                              color: const Color(0xee111119),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black54,
                                  blurRadius: 20,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (speaker.isNotEmpty) ...[
                                  Text(
                                    speaker,
                                    style: const TextStyle(
                                      color: Color(0xffa78bfa),
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                Text(
                                  text,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 19,
                                    height: 1.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_showChoices) _buildChoiceOverlay(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceOverlay() {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '선택지를 고르세요',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 18),
                ..._choices.map(
                  (choice) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xff17131f),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 18,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _selectChoice(choice),
                        child: Text(
                          _replaceName(choice['text']),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StorySnapshot {
  const _StorySnapshot({
    required this.lines,
    required this.index,
    required this.score,
    required this.backgroundImage,
    required this.characterImage,
    required this.showChoices,
    required this.choices,
  });

  final List<Map<String, dynamic>> lines;
  final int index;
  final int score;
  final String? backgroundImage;
  final String? characterImage;
  final bool showChoices;
  final List<Map<String, dynamic>> choices;
}

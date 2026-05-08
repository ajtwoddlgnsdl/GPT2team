import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

class MinigameScreen extends StatefulWidget {
  const MinigameScreen({super.key});

  @override
  State<MinigameScreen> createState() => _MinigameScreenState();
}

class _MinigameScreenState extends State<MinigameScreen> {
  static const int _pairCount = 6;

  final Random _random = Random();
  final List<_CardItem> _cards = [];

  int? _firstSelectedIndex;
  int? _secondSelectedIndex;
  bool _isResolvingTurn = false;
  int _matchedPairs = 0;
  int _turnCount = 0;
  Timer? _flipBackTimer;

  bool get _isClear => _matchedPairs == _pairCount;

  @override
  void initState() {
    super.initState();
    _startNewGame();
  }

  void _startNewGame() {
    _flipBackTimer?.cancel();

    final symbols = <String>['A', 'B', 'C', 'D', 'E', 'F'];
    final deck = <_CardItem>[
      for (final symbol in symbols) _CardItem(symbol: symbol),
      for (final symbol in symbols) _CardItem(symbol: symbol),
    ]..shuffle(_random);

    setState(() {
      _cards
        ..clear()
        ..addAll(deck);
      _firstSelectedIndex = null;
      _secondSelectedIndex = null;
      _isResolvingTurn = false;
      _matchedPairs = 0;
      _turnCount = 0;
    });
  }

  void _onCardTapped(int index) {
    if (_isResolvingTurn || _isClear) return;

    final card = _cards[index];
    if (card.isFaceUp || card.isMatched) return;

    setState(() {
      card.isFaceUp = true;
    });

    if (_firstSelectedIndex == null) {
      _firstSelectedIndex = index;
      return;
    }

    _secondSelectedIndex = index;
    _turnCount++;
    _isResolvingTurn = true;

    final firstCard = _cards[_firstSelectedIndex!];
    final secondCard = _cards[_secondSelectedIndex!];

    if (firstCard.symbol == secondCard.symbol) {
      setState(() {
        firstCard.isMatched = true;
        secondCard.isMatched = true;
        _matchedPairs++;
      });
      _resetTurn();
      return;
    }

    _flipBackTimer = Timer(const Duration(milliseconds: 850), () {
      if (!mounted) return;

      setState(() {
        firstCard.isFaceUp = false;
        secondCard.isFaceUp = false;
      });
      _resetTurn();
    });
  }

  void _resetTurn() {
    _firstSelectedIndex = null;
    _secondSelectedIndex = null;
    _isResolvingTurn = false;
  }

  @override
  void dispose() {
    _flipBackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('\uCE74\uB4DC \uB9DE\uCD94\uAE30'),
        backgroundColor: const Color(0xFF141414),
      ),
      backgroundColor: const Color(0xFF111111),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildInfoPanel(),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  itemCount: _cards.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.74,
                  ),
                  itemBuilder: (context, index) {
                    return _MemoryCard(
                      card: _cards[index],
                      onTap: () => _onCardTapped(index),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              if (_isClear) _buildClearPanel() else _buildHintText(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1D1D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '\uAC19\uC740 \uCE74\uB4DC \uB450 \uC7A5\uC744 \uCC3E\uC544\uBCF4\uC138\uC694.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '\uB9DE\uCD98 \uCE74\uB4DC: $_matchedPairs / $_pairCount',
            style: const TextStyle(color: Colors.white70, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            '\uC2DC\uB3C4 \uD69F\uC218: $_turnCount',
            style: const TextStyle(color: Colors.white70, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildHintText() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Text(
        '\uCE74\uB4DC\uB97C \uB450 \uC7A5\uC529 \uB20C\uB7EC\uC11C \uAC19\uC740 \uC9DD\uC744 \uCC3E\uC73C\uBA74 \uB429\uB2C8\uB2E4.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white60, fontSize: 14),
      ),
    );
  }

  Widget _buildClearPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF222038),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFC857)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '\uD074\uB9AC\uC5B4!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '\uCD1D $_turnCount\uBC88 \uB9CC\uC5D0 \uBAA8\uB4E0 \uCE74\uB4DC\uB97C \uB9DE\uD614\uC5B4\uC694.',
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _startNewGame,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('\uB2E4\uC2DC \uD558\uAE30'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC857),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    '\uB85C\uBE44\uB85C \uB3CC\uC544\uAC00\uAE30',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardItem {
  _CardItem({
    required this.symbol,
  });

  final String symbol;
  bool isFaceUp = false;
  bool isMatched = false;
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({
    required this.card,
    required this.onTap,
  });

  final _CardItem card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isVisible = card.isFaceUp || card.isMatched;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: isVisible ? const Color(0xFFF6E7CB) : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: card.isMatched
                ? const Color(0xFFFFC857)
                : Colors.white.withValues(alpha: 0.14),
            width: card.isMatched ? 2.4 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: isVisible
                ? Text(
                    card.symbol,
                    key: ValueKey('front-${card.symbol}-${card.isMatched}'),
                    style: const TextStyle(
                      color: Color(0xFF3A2A12),
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : const Icon(
                    Icons.question_mark_rounded,
                    key: ValueKey('back'),
                    color: Colors.white70,
                    size: 34,
                  ),
          ),
        ),
      ),
    );
  }
}

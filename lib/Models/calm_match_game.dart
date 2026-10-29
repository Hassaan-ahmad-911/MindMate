import 'dart:math' as math;

/// The six pictures on the cards.
enum CalmSymbol {
  leaf('leaf'),
  moon('moon'),
  wave('wave'),
  heart('heart'),
  star('star'),
  sun('sun');

  const CalmSymbol(this.label);

  final String label;
}

enum CardFace { down, up, matched }

/// What a tap on a card did.
enum FlipResult {
  /// The tap was ignored (cards are locked, or the card is already face up).
  ignored,

  /// The first card of a turn turned over.
  flipped,

  /// The second card matched the first.
  matched,

  /// The second card did not match. Call [CalmMatchGame.resolveMismatch]
  /// after a short pause to turn both back.
  mismatch,
}

/// The rules of Calm match: 12 cards, 6 pairs, no timer and no score. Pure
/// Dart; the screen decides when to call [CalmMatchGame.resolveMismatch].
class CalmMatchGame {
  CalmMatchGame({math.Random? random})
    : symbols = _shuffled(random ?? math.Random()) {
    faces = List<CardFace>.filled(cardCount, CardFace.down);
  }

  static const int pairCount = 6;
  static const int cardCount = pairCount * 2;

  /// The picture on each card, in grid order.
  final List<CalmSymbol> symbols;

  late final List<CardFace> faces;

  int _turns = 0;
  int _pairsFound = 0;

  /// A turn is two cards turned over.
  int get turns => _turns;

  int get pairsFound => _pairsFound;

  bool get isComplete => _pairsFound == pairCount;

  /// Face-up cards that have not matched yet.
  List<int> get showing => <int>[
    for (int i = 0; i < cardCount; i += 1)
      if (faces[i] == CardFace.up) i,
  ];

  /// Two unmatched cards are showing: taps wait until they turn back.
  bool get isLocked => showing.length >= 2;

  FlipResult flip(int index) {
    if (index < 0 || index >= cardCount) {
      return FlipResult.ignored;
    }
    if (isLocked || faces[index] != CardFace.down) {
      return FlipResult.ignored;
    }

    faces[index] = CardFace.up;
    final List<int> open = showing;
    if (open.length < 2) {
      return FlipResult.flipped;
    }

    _turns += 1;
    final int first = open.first;
    final int second = open.last;
    if (symbols[first] == symbols[second]) {
      faces[first] = CardFace.matched;
      faces[second] = CardFace.matched;
      _pairsFound += 1;
      return FlipResult.matched;
    }
    return FlipResult.mismatch;
  }

  /// Turns the two unmatched cards face down again.
  void resolveMismatch() {
    for (final int index in showing) {
      faces[index] = CardFace.down;
    }
  }

  /// "Face-down card", "Face up: leaf" or "Matched: leaf".
  String labelFor(int index) {
    final String name = symbols[index].label;
    switch (faces[index]) {
      case CardFace.down:
        return 'Face-down card';
      case CardFace.up:
        return 'Face up: $name';
      case CardFace.matched:
        return 'Matched: $name';
    }
  }

  static List<CalmSymbol> _shuffled(math.Random random) {
    final List<CalmSymbol> cards = <CalmSymbol>[
      ...CalmSymbol.values,
      ...CalmSymbol.values,
    ];
    cards.shuffle(random);
    return cards;
  }
}

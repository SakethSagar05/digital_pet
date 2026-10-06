// In-Class Activity 07: Digital Pet State Lab
//
// Core: editable name, bounded happiness/hunger meters, mood label + ColorFiltered
//       tint, feed/play/reset, 30 s hunger timer, 3-minute win, hunger/happiness loss.
// Advanced feature 1: Session controls (pause/resume + restart).
// Advanced feature 2: Visual polish & accessible motion (action bounce, living
//       meters, expression switch, mood tint + size, reduced-motion support).

import 'dart:async';

import 'package:flutter/material.dart';

void main() => runApp(const DigitalPetApp());

class DigitalPetApp extends StatelessWidget {
  const DigitalPetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Digital Pet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const DigitalPetScreen(
        hungerInterval: Duration(seconds: 5),
        winDuration: Duration(seconds: 10),
      ),
    );
  }
}

enum Outcome { playing, won, lost }

class DigitalPetScreen extends StatefulWidget {
  const DigitalPetScreen({
    super.key,
    // Production values. Override only for testing (e.g. Duration(seconds: 5)).
    this.hungerInterval = const Duration(seconds: 30),
    this.winDuration = const Duration(minutes: 3),
  });

  final Duration hungerInterval;
  final Duration winDuration;

  @override
  State<DigitalPetScreen> createState() => _DigitalPetScreenState();
}

class _DigitalPetScreenState extends State<DigitalPetScreen> {
  static const int _initialHappiness = 50;
  static const int _initialHunger = 50;
  static const String _defaultName = 'Pip';

  // ---- State (single source of truth) ----
  String _petName = _defaultName;
  int _happiness = _initialHappiness;
  int _hunger = _initialHunger;
  Outcome _outcome = Outcome.playing;
  bool _paused = false;
  bool _bouncing = false; // short-lived animation state only
  String _lastAction = 'Choose an action to care for your pet.';

  // ---- Owned resources ----
  Timer? _hungerTimer;
  Timer? _winTimer;
  Timer? _bounceTimer;
  DateTime? _winStartedAt;
  late Duration _winRemaining;
  final TextEditingController _nameController =
      TextEditingController(text: _defaultName);

  @override
  void initState() {
    super.initState();
    _winRemaining = widget.winDuration;
    _startHungerTimer(); // created once here, never in build()
  }

  @override
  void dispose() {
    _hungerTimer?.cancel();
    _winTimer?.cancel();
    _bounceTimer?.cancel();
    _nameController.dispose();
    super.dispose();
  }

  // ---- Derived values (never stored separately) ----
  bool get _isPlaying => _outcome == Outcome.playing;
  bool get _canCare => _isPlaying && !_paused;
  bool get _winCountdownActive => _winTimer != null;

  String get _moodLabel => _happiness > 70
      ? 'Happy'
      : _happiness >= 30
          ? 'Neutral'
          : 'Unhappy';

  String get _moodEmoji => _happiness > 70
      ? '😄'
      : _happiness >= 30
          ? '😐'
          : '😞';

  Color get _moodColor {
    if (_happiness > 70) return Colors.green;
    if (_happiness >= 30) return Colors.yellow;
    return Colors.red;
  }

  double get _petScale => _happiness > 70
      ? 1.06
      : _happiness < 30
          ? 0.94
          : 1.0;

  String get _petMessage {
    if (_outcome == Outcome.lost) return 'I need a rest.';
    if (_outcome == Outcome.won) return 'Best day ever!';
    if (_paused) return 'Zzz... (paused)';
    if (_hunger > 80) return "I'm starving!";
    if (_happiness <= 30) return 'Play with me?';
    return "Hi, I'm $_petName!";
  }

  int _clampMeter(int value) => value.clamp(0, 100).toInt();

  String _signed(int n) => n > 0 ? '+$n' : '$n';

  // ---- Timers ----
  void _startHungerTimer() {
    _hungerTimer?.cancel(); // guarantees exactly one hunger timer
    _hungerTimer = Timer.periodic(widget.hungerInterval, (_) => _onHungerTick());
  }

  void _onHungerTick() {
    if (!mounted) return;
    if (!_canCare) return;
    _step(() {
      if (_hunger + 5 > 100) {
        // Overflow tick: clamp hunger and penalize happiness.
        _hunger = 100;
        _happiness = _clampMeter(_happiness - 20);
      } else {
        _hunger += 5; // 95 -> 100 is allowed without a penalty
      }
    });
  }

  void _startWinTimer(Duration duration) {
    _winTimer?.cancel();
    _winRemaining = duration;
    _winStartedAt = DateTime.now();
    _winTimer = Timer(duration, _onWinTimerFired);
  }

  void _cancelWinTimer() {
    _winTimer?.cancel();
    _winTimer = null;
    _winStartedAt = null;
  }

  void _onWinTimerFired() {
    _winTimer = null;
    _winStartedAt = null;
    if (!mounted || !_canCare || _happiness <= 80) return;
    setState(() {
      _outcome = Outcome.won;
      _hungerTimer?.cancel();
      _hungerTimer = null;
      _winRemaining = widget.winDuration;
    });
  }

  // ---- State transitions ----
  /// Applies one change to the meters and re-evaluates the outcome inside the
  /// same setState call, so related fields always update together.
  void _step(VoidCallback change) {
    if (!_canCare) return;
    setState(() {
      change();
      _evaluateOutcome();
    });
  }

  void _evaluateOutcome() {
    // Loss: hunger is 100 and happiness is 10 or lower.
    if (_hunger >= 100 && _happiness <= 10) {
      _outcome = Outcome.lost;
      _hungerTimer?.cancel();
      _hungerTimer = null;
      _cancelWinTimer();
      return;
    }
    if (_happiness > 80) {
      // Strictly above 80 starts the continuous-win countdown (once).
      if (_winTimer == null) _startWinTimer(_winRemaining);
    } else {
      // 80 or lower cancels and clears it; the next crossing starts fresh.
      _cancelWinTimer();
      _winRemaining = widget.winDuration;
    }
  }

  void _feedPet() {
    if (!_canCare) return;
    final oldHunger = _hunger;
    final oldHappiness = _happiness;
    final nextHunger = _clampMeter(_hunger - 10);
    final happinessChange = nextHunger < 30 ? -20 : 10;
    final nextHappiness = _clampMeter(_happiness + happinessChange);
    _step(() {
      _hunger = nextHunger;
      _happiness = nextHappiness;
      _lastAction = 'Fed: Hunger ${_signed(nextHunger - oldHunger)}, '
          'Happiness ${_signed(nextHappiness - oldHappiness)}.';
    });
    _triggerBounce();
  }

  void _playWithPet() {
    if (!_canCare) return;
    final oldHunger = _hunger;
    final oldHappiness = _happiness;
    final nextHappiness = _clampMeter(_happiness + 10);
    final nextHunger = _clampMeter(_hunger + 5);
    _step(() {
      _happiness = nextHappiness;
      _hunger = nextHunger;
      _lastAction = 'Played: Happiness ${_signed(nextHappiness - oldHappiness)}, '
          'Hunger ${_signed(nextHunger - oldHunger)}.';
    });
    _triggerBounce();
  }

  // ---- Session controls ----
  void _pause() {
    if (!_canCare) return;
    setState(() {
      // Freeze the win countdown by remembering how much time is left.
      if (_winStartedAt != null) {
        final elapsed = DateTime.now().difference(_winStartedAt!);
        _winRemaining = _winRemaining - elapsed;
        if (_winRemaining < Duration.zero) _winRemaining = Duration.zero;
      }
      _cancelWinTimer();
      _hungerTimer?.cancel();
      _hungerTimer = null;
      _paused = true;
      _lastAction = 'Paused. Timers are stopped.';
    });
  }

  void _resume() {
    if (!_isPlaying || !_paused) return;
    setState(() {
      _paused = false;
      _startHungerTimer();
      _evaluateOutcome(); // restarts the win countdown with the remaining time
      _lastAction = 'Resumed.';
    });
  }

  void _restart() {
    _hungerTimer?.cancel();
    _hungerTimer = null;
    _cancelWinTimer();
    _bounceTimer?.cancel();
    setState(() {
      _happiness = _initialHappiness;
      _hunger = _initialHunger;
      _outcome = Outcome.playing;
      _paused = false;
      _bouncing = false;
      _winRemaining = widget.winDuration;
      _lastAction = 'Restarted: Happiness $_initialHappiness, '
          'Hunger $_initialHunger.';
    });
    _startHungerTimer();
  }

  // ---- Name ----
  void _confirmName() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name for your pet.')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _petName = name;
      _lastAction = 'Your pet is now named $name.';
    });
  }

  // ---- Motion ----
  void _triggerBounce() {
    if (MediaQuery.of(context).disableAnimations) return;
    _bounceTimer?.cancel(); // an older reset must not end a newer bounce
    setState(() => _bouncing = true);
    _bounceTimer = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() => _bouncing = false);
    });
  }

  // ---- UI ----
  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Digital Pet')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildNameRow(),
                  const SizedBox(height: 16),
                  _buildPet(reduceMotion),
                  const SizedBox(height: 8),
                  _buildMoodChip(scheme),
                  const SizedBox(height: 8),
                  _buildSpeechBubble(reduceMotion, scheme),
                  if (!_isPlaying) ...[
                    const SizedBox(height: 12),
                    _buildOutcomeBanner(scheme),
                  ],
                  const SizedBox(height: 16),
                  _MeterBar(
                    label: 'Happiness',
                    value: _happiness,
                    reduceMotion: reduceMotion,
                  ),
                  const SizedBox(height: 8),
                  _MeterBar(
                    label: 'Hunger',
                    value: _hunger,
                    reduceMotion: reduceMotion,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _statusLine,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _lastAction,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _statusLine {
    if (_outcome == Outcome.won) return 'Win timer complete. Hunger timer stopped.';
    if (_outcome == Outcome.lost) return 'Game over. Timers stopped.';
    if (_paused) return 'Paused: hunger and win timers are stopped.';
    if (_winCountdownActive) {
      return 'Win countdown running: keep happiness above 80.';
    }
    return 'Win countdown idle: happiness must be above 80.';
  }

  Widget _buildNameRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _nameController,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _confirmName(),
            maxLength: 20,
            decoration: const InputDecoration(
              labelText: 'Pet name',
              border: OutlineInputBorder(),
              counterText: '',
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(onPressed: _confirmName, child: const Text('Set name')),
      ],
    );
  }

  Widget _buildPet(bool reduceMotion) {
    final scale = _petScale * (_bouncing ? 1.12 : 1.0);
    return Column(
      children: [
        Text(
          _petName,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        AnimatedScale(
          scale: scale,
          duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(_moodColor, BlendMode.modulate),
            child: Image.asset(
              'assets/pet.png',
              height: 200,
              semanticLabel: '$_petName, a $_moodLabel pet',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMoodChip(ColorScheme scheme) {
    // Text + emoji so color is never the only mood signal.
    return Center(
      child: Chip(
        avatar: Text(_moodEmoji),
        label: Text('Mood: $_moodLabel'),
      ),
    );
  }

  Widget _buildSpeechBubble(bool reduceMotion, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: AnimatedSwitcher(
        duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 300),
        child: Text(
          _petMessage,
          key: ValueKey(_petMessage),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }

  Widget _buildOutcomeBanner(ColorScheme scheme) {
    final won = _outcome == Outcome.won;
    return Card(
      color: won ? scheme.primaryContainer : scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          won
              ? 'You win! Happiness stayed above 80 for the full time.'
              : 'Game over: hunger reached 100 and happiness fell to 10 or lower.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: _canCare ? _feedPet : null,
          icon: const Icon(Icons.restaurant),
          label: const Text('Feed'),
        ),
        FilledButton.icon(
          onPressed: _canCare ? _playWithPet : null,
          icon: const Icon(Icons.sports_tennis),
          label: const Text('Play'),
        ),
        OutlinedButton.icon(
          onPressed: _isPlaying ? (_paused ? _resume : _pause) : null,
          icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
          label: Text(_paused ? 'Resume' : 'Pause'),
        ),
        OutlinedButton.icon(
          onPressed: _restart,
          icon: const Icon(Icons.restart_alt),
          label: const Text('Restart'),
        ),
      ],
    );
  }
}

/// A meter whose bar glides to the current value. The number shown always
/// comes from state; the animation only affects how the bar is drawn.
class _MeterBar extends StatelessWidget {
  const _MeterBar({
    required this.label,
    required this.value,
    required this.reduceMotion,
  });

  final String label;
  final int value;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      value: '$value out of 100',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: Text('$label: $value / 100')),
          const SizedBox(height: 4),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: value / 100),
            duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            builder: (context, animatedValue, _) => LinearProgressIndicator(
              value: animatedValue,
              minHeight: 10,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ],
      ),
    );
  }
}

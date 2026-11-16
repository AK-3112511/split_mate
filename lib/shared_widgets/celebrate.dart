import 'dart:math' as math;
import 'package:confetti/confetti.dart';
import 'package:material_ui/material_ui.dart';
import '../core/theme/tokens.dart';
import '../core/utils/haptics.dart';

/// One-shot confetti burst over the whole app (e.g. a debt reaches ₹0).
class Celebrate {
  Celebrate._();

  static void show(BuildContext context) {
    Haptics.success();
    if (Motion.reduced(context)) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    late OverlayEntry entry;
    entry = OverlayEntry(builder: (_) => _ConfettiBurst(onDone: () => entry.remove()));
    overlay.insert(entry);
  }
}

class _ConfettiBurst extends StatefulWidget {
  final VoidCallback onDone;
  const _ConfettiBurst({required this.onDone});

  @override
  State<_ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<_ConfettiBurst> {
  late final ConfettiController _controller =
      ConfettiController(duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    _controller.play();
    Future.delayed(const Duration(milliseconds: 3200), () {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConfettiWidget(
          confettiController: _controller,
          blastDirection: math.pi / 2,
          blastDirectionality: BlastDirectionality.explosive,
          emissionFrequency: 0.06,
          numberOfParticles: 24,
          maxBlastForce: 22,
          minBlastForce: 8,
          gravity: 0.25,
          shouldLoop: false,
          colors: Palette.pops,
        ),
      ),
    );
  }
}

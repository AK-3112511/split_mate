import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared_widgets/logo_mark.dart';

/// True once the intro animation has played (the router waits for it).
final splashDoneProvider = StateProvider<bool>((ref) => false);

/// ~5.4s story intro:
///  1. Two coin halves (two friends) fly in spinning from opposite corners.
///  2. They meet and *click* into one whole coin — haptic, bump, shockwave, sparks.
///  3. The coin flips once (a coin toss).
///  4. The logo tile pops in behind it; the coin eases back into the split logo.
///  5. "SplitMate" bounces in letter by letter, then the tagline sticker.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 5400);
  late final AnimationController _c = AnimationController(vsync: this, duration: _duration);
  bool _clicked = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(() {
      if (!_clicked && _c.value >= 0.30) {
        _clicked = true;
        HapticFeedback.mediumImpact(); // the halves click together
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (Motion.reduced(context)) {
        _c.value = 1;
        _finish();
        return;
      }
      _c.forward().whenComplete(_finish);
    });
  }

  void _finish() {
    if (mounted) ref.read(splashDoneProvider.notifier).state = true;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _t(double from, double to, [Curve curve = Curves.easeOutCubic]) {
    final v = ((_c.value - from) / (to - from)).clamp(0.0, 1.0);
    return curve.transform(v);
  }

  @override
  Widget build(BuildContext context) {
    const coin = 150.0;
    final size = MediaQuery.sizeOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: Palette.yellow,
        body: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            // 1. fly-in (0.04 → 0.30)
            final fly = _t(0.04, 0.30, Curves.easeOutCubic);
            final far = size.width * 0.9;
            final spin = (1 - fly) * math.pi * 1.6;
            // 2. click + bump (0.30 → 0.40)
            final bump = 1 + 0.18 * math.sin(math.pi * _t(0.30, 0.38));
            final joinGap = 18 * (1 - _t(0.26, 0.31, Curves.easeIn));
            // 3. flip (0.40 → 0.52)
            final flip = _t(0.40, 0.52, Curves.easeInOutCubic);
            final flipScaleX = math.cos(flip * math.pi * 2).abs().clamp(0.08, 1.0);
            // 4. tile + settle into the logo pose (0.52 → 0.64)
            final tile = _t(0.52, 0.64, Curves.elasticOut);
            final settle = _t(0.56, 0.66, Curves.easeOutBack);
            final logoGap = 6 * settle;
            final coinScale = 1 - 0.30 * settle;
            final lift = -48.0 * _t(0.60, 0.72, Curves.easeOutCubic);
            final gap = joinGap + logoGap;

            Widget half(bool left) {
              final dir = left ? -1.0 : 1.0;
              final dx = dir * (far * (1 - fly) + gap);
              final dy = dir * (size.height * 0.35 * (1 - fly) + gap);
              return Transform.translate(
                offset: Offset(dx, dy),
                child: Transform.rotate(angle: dir * spin, child: CoinHalf(size: coin, left: left)),
              );
            }

            return Stack(
              children: [
                // Shockwave rings when the halves click.
                for (final (delay, width) in [(0.30, 4.0), (0.34, 2.5)])
                  Center(
                    child: Transform.translate(
                      offset: Offset(0, lift),
                      child: Opacity(
                        opacity: _c.value < delay ? 0 : (1 - _t(delay, delay + 0.16)),
                        child: Container(
                          width: coin + 280 * _t(delay, delay + 0.16),
                          height: coin + 280 * _t(delay, delay + 0.16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Palette.ink, width: width),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Pop-colour sparks.
                if (_c.value >= 0.30 && _c.value < 0.52)
                  for (var i = 0; i < 10; i++)
                    Center(
                      child: Builder(builder: (_) {
                        final p = _t(0.30, 0.50, Curves.easeOutCubic);
                        final a = i * math.pi * 2 / 10 + 0.3;
                        final d = 40 + 150 * p;
                        return Transform.translate(
                          offset: Offset(math.cos(a) * d, math.sin(a) * d + lift),
                          child: Opacity(
                            opacity: 1 - p,
                            child: Transform.rotate(
                              angle: a + p * 3,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: Palette.pops[(i + 1) % Palette.pops.length],
                                  borderRadius: BorderRadius.circular(i.isEven ? 7 : 3),
                                  border: Border.all(color: Palette.ink, width: 2),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                // The logo tile behind the coin.
                Center(
                  child: Transform.translate(
                    offset: Offset(0, lift),
                    child: Transform.rotate(
                      angle: -0.08 * tile,
                      child: Transform.scale(
                        scale: tile,
                        // Empty tile: the flying coin lands in it (no doubled coin).
                        child: Opacity(
                          opacity: _t(0.52, 0.56),
                          child: Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              color: Palette.yellow,
                              borderRadius: BorderRadius.circular(150 * 0.24),
                              border: Border.all(color: Palette.ink, width: 150 * 0.024),
                              boxShadow: const [BoxShadow(color: Palette.ink, offset: Offset(7.5, 7.5))],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // The two halves (hidden once the tile's own coin takes over).
                if (_c.value < 0.66)
                  Center(
                    child: Transform.translate(
                      offset: Offset(0, lift),
                      child: Opacity(
                        opacity: 1 - _t(0.62, 0.66),
                        child: Transform.scale(
                          scale: coinScale * (_c.value < 0.40 ? (_c.value >= 0.30 ? bump : 1) : 1),
                          child: Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.diagonal3Values(flipScaleX, 1, 1),
                            child: SizedBox(
                              width: coin,
                              height: coin,
                              child: Stack(children: [half(true), half(false)]),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Logo coin re-split inside the tile (final pose).
                if (_c.value >= 0.62)
                  Center(
                    child: Transform.translate(
                      offset: Offset(0, lift),
                      child: Transform.rotate(
                        angle: -0.08,
                        child: Opacity(
                          opacity: _t(0.62, 0.66),
                          child: LogoMark(size: 150, split: settle, tile: true),
                        ),
                      ),
                    ),
                  ),
                // Wordmark + tagline.
                Center(
                  child: Transform.translate(
                    offset: Offset(0, 96 + lift * 0.2),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var i = 0; i < 'SplitMate'.length; i++)
                              Builder(builder: (context) {
                                final start = 0.66 + i * 0.022;
                                final v = _t(start, start + 0.10, Curves.easeOutBack);
                                return Opacity(
                                  opacity: _t(start, start + 0.04),
                                  child: Transform.translate(
                                    offset: Offset(0, 30 * (1 - v)),
                                    child: Transform.rotate(
                                      angle: (i.isEven ? -0.12 : 0.12) * (1 - v),
                                      child: Text(
                                        'SplitMate'[i],
                                        style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                              color: Palette.ink,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: -1,
                                            ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                          ],
                        ),
                        const SizedBox(height: Space.sm),
                        Builder(builder: (context) {
                          final v = _t(0.86, 0.94, Curves.elasticOut);
                          return Opacity(
                            opacity: _t(0.86, 0.89),
                            child: Transform.rotate(
                              angle: -0.04,
                              child: Transform.scale(
                                scale: 0.6 + 0.4 * v,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Palette.paper,
                                    borderRadius: Radii.chip,
                                    border: Border.all(color: Palette.ink, width: 2.5),
                                    boxShadow: const [BoxShadow(color: Palette.ink, offset: Offset(4, 4))],
                                  ),
                                  child: Text(
                                    'Split bills. Stay friends.',
                                    style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Palette.ink),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/aurora_colors.dart';
import '../core/theme/tokens.dart';
import '../core/utils/haptics.dart';
import 'feedback.dart';
import 'motion.dart';

/// Prominent, tap-to-copy code with a share button (friend & group codes).
class CodeChip extends StatelessWidget {
  final String? code;
  final String label;
  final String shareText;
  final bool onGradient;

  const CodeChip({
    super.key,
    required this.code,
    required this.label,
    required this.shareText,
    this.onGradient = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    final ready = code != null && code!.isNotEmpty;
    final fg = c.text;
    final muted = c.textMuted;
    final bg = c.surface;

    return Row(
      children: [
        Expanded(
          child: Pressable(
            borderRadius: Radii.tile,
            semanticLabel: ready ? 'Copy $label $code' : null,
            onTap: !ready
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: code!));
                    Haptics.success();
                    Toast.success('$label copied');
                  },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: Radii.tile,
                border: Border.all(color: c.ink, width: Brutal.borderThin),
                boxShadow: c.hardShadow(Brutal.shadowSmall),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: context.text.labelSmall?.copyWith(color: muted)),
                        const SizedBox(height: 2),
                        Text(
                          ready ? code! : '······',
                          style: context.text.titleLarge?.copyWith(
                            color: fg,
                            letterSpacing: 4,
                            fontFeatures: AppTheme.tabular,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.copy_rounded, size: 20, color: muted),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: Space.xs),
        Tooltip(
          message: 'Share',
          child: Pressable(
            borderRadius: Radii.tile,
            semanticLabel: 'Share $label',
            onTap: !ready ? null : () => Share.share(shareText),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Palette.violet,
                borderRadius: Radii.tile,
                border: Border.all(color: c.ink, width: Brutal.borderThin),
                boxShadow: c.hardShadow(Brutal.shadowSmall),
              ),
              child: Icon(Icons.ios_share_rounded, color: c.onPop),
            ),
          ),
        ),
      ],
    );
  }
}

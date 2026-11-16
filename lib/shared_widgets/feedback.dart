import 'package:material_ui/material_ui.dart';
import '../core/theme/aurora_colors.dart';
import '../core/theme/tokens.dart';
import '../core/utils/friendly_error.dart';
import '../core/utils/haptics.dart';
import '../core/utils/write_helper.dart';
import 'buttons.dart';

/// Global messenger so toasts work even after the calling screen was popped.
final GlobalKey<ScaffoldMessengerState> rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

enum ToastType { success, error, info, warning }

class Toast {
  Toast._();

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? show(
    String message, {
    ToastType type = ToastType.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    final messenger = rootMessengerKey.currentState;
    if (messenger == null) return null;
    final ctx = rootMessengerKey.currentContext!;
    final c = ctx.aurora;
    final (icon, color) = switch (type) {
      ToastType.success => (Icons.check_circle_rounded, c.positive),
      ToastType.error => (Icons.error_rounded, c.negative),
      ToastType.info => (Icons.info_rounded, c.secondary),
      ToastType.warning => (Icons.warning_amber_rounded, c.warning),
    };
    if (type == ToastType.error) Haptics.warning();
    messenger.hideCurrentSnackBar();
    return messenger.showSnackBar(SnackBar(
      duration: duration,
      content: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: Space.sm),
          Expanded(child: Text(message)),
        ],
      ),
      action: actionLabel == null ? null : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
    ));
  }

  static void success(String message) => show(message, type: ToastType.success);
  static void info(String message) => show(message, type: ToastType.info);
  static void error(Object error) => show(friendlyError(error), type: ToastType.error);

  /// "Saved" vs "Saved — will sync when you're online".
  static void saved(WriteOutcome outcome, String message) {
    if (outcome == WriteOutcome.pending) {
      show('$message — will sync when you\'re online', type: ToastType.info);
    } else {
      success(message);
    }
  }
}

/// Opens a themed modal bottom sheet that resizes for the keyboard.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool scrollable = true,
  bool dismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: dismissible,
    enableDrag: dismissible,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: scrollable ? SingleChildScrollView(child: builder(ctx)) : builder(ctx),
    ),
  );
}

/// Standard padding/title layout used inside sheets.
class SheetBody extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;

  const SheetBody({
    super.key,
    this.title,
    this.subtitle,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: crossAxisAlignment,
          children: [
            if (title != null) Text(title!, style: context.text.titleLarge),
            if (subtitle != null) ...[
              const SizedBox(height: Space.xxs),
              Text(subtitle!, style: context.text.bodyMedium?.copyWith(color: context.aurora.textMuted)),
            ],
            if (title != null || subtitle != null) const SizedBox(height: Space.lg),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Asks the user to confirm. Returns true only on an explicit "yes".
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
  IconData? icon,
  bool showCancel = true,
}) async {
  final result = await showAppSheet<bool>(
    context,
    builder: (ctx) {
      final c = ctx.aurora;
      return SheetBody(
        children: [
          Center(
            child: Transform.rotate(
              angle: 0, // serious actions stay straight
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: destructive ? c.negativeFill : c.cta,
                  borderRadius: Radii.card,
                  border: c.inkBorder,
                  boxShadow: c.hardShadow(Brutal.shadowSmall),
                ),
                child: Icon(icon ?? (destructive ? Icons.warning_amber_rounded : Icons.help_outline_rounded),
                    color: c.onPop, size: 32),
              ),
            ),
          ),
          const SizedBox(height: Space.md),
          Text(title, textAlign: TextAlign.center, style: ctx.text.titleLarge),
          const SizedBox(height: Space.xs),
          Text(message, textAlign: TextAlign.center, style: ctx.text.bodyMedium?.copyWith(color: c.textMuted)),
          const SizedBox(height: Space.xl),
          PrimaryButton(
            label: confirmLabel,
            color: destructive ? c.negativeFill : null,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
          if (showCancel) ...[
            const SizedBox(height: Space.sm),
            SecondaryButton(label: 'Cancel', onPressed: () => Navigator.of(ctx).pop(false)),
          ],
        ],
      );
    },
  );
  return result ?? false;
}

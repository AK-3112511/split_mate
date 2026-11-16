import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import '../core/theme/aurora_colors.dart';
import '../core/theme/tokens.dart';
import '../core/utils/image_codec.dart';
import '../core/utils/initials.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/friends/data/friends_repository.dart';

/// Photo (base64 or URL) or initials on a person-specific gradient.
class PersonAvatar extends StatelessWidget {
  final String seed;
  final String? name;
  final String? photo;
  final double size;
  final bool ring;

  const PersonAvatar({
    super.key,
    required this.seed,
    this.name,
    this.photo,
    this.size = 44,
    this.ring = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    final pop = Palette.popFor(seed);
    Widget inner;
    final bytes = ImageCodec.isDataUri(photo) ? ImageCodec.decode(photo) : null;
    if (bytes != null) {
      inner = Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: size,
        height: size,
        cacheWidth: (size * 3).round(),
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _initials(context, pop),
      );
    } else if (ImageCodec.isNetwork(photo)) {
      inner = CachedNetworkImage(
        imageUrl: photo!,
        fit: BoxFit.cover,
        width: size,
        height: size,
        placeholder: (_, __) => _initials(context, pop),
        errorWidget: (_, __, ___) => _initials(context, pop),
      );
    } else {
      inner = _initials(context, pop);
    }
    return Semantics(
      label: name,
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: c.ink, width: size < 30 ? 1.5 : Brutal.borderThin),
          boxShadow: ring ? [BoxShadow(color: c.bg, spreadRadius: 2)] : null,
        ),
        child: ClipOval(child: inner),
      ),
    );
  }

  Widget _initials(BuildContext context, Color pop) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: pop,
      child: Text(
        initialsOf(name),
        style: TextStyle(
          color: context.aurora.onPop,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.36,
          height: 1,
        ),
      ),
    );
  }
}

/// Avatar for any user id: loads their public profile and my nickname for them.
class UserAvatar extends ConsumerWidget {
  final String uid;
  final double size;
  final bool ring;
  const UserAvatar({super.key, required this.uid, this.size = 44, this.ring = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider(uid)).valueOrNull;
    final name = ref.watch(realNameProvider(uid));
    return PersonAvatar(seed: uid, name: name, photo: profile?.avatar, size: size, ring: ring);
  }
}

/// Overlapping avatars ("+3" when there are more).
class AvatarStack extends StatelessWidget {
  final List<String> uids;
  final double size;
  final int max;
  const AvatarStack({super.key, required this.uids, this.size = 28, this.max = 4});

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    final shown = uids.take(max).toList();
    final extra = uids.length - shown.length;
    final step = size * 0.68;
    final count = shown.length + (extra > 0 ? 1 : 0);
    return SizedBox(
      height: size,
      width: count == 0 ? 0 : step * (count - 1) + size,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(left: i * step, child: UserAvatar(uid: shown[i], size: size, ring: true)),
          if (extra > 0)
            Positioned(
              left: shown.length * step,
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.surfaceHigh,
                  border: Border.all(color: c.ink, width: 1.5),
                  boxShadow: [BoxShadow(color: c.bg, spreadRadius: 2)],
                ),
                child: Text('+$extra', style: context.text.labelSmall?.copyWith(color: c.text, letterSpacing: 0)),
              ),
            ),
        ],
      ),
    );
  }
}

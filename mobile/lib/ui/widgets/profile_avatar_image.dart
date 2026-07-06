import 'dart:io';

import 'package:flutter/material.dart';

/// The image content of a user avatar, sized to fill its parent with
/// `BoxFit.cover`. The caller clips it to whatever shape it wants (a circle in
/// the dashboard header, a rounded square on the profile screen).
///
/// It resolves the source correctly for the active data mode, which is the whole
/// point of centralizing this: in **Private mode** `avatarUrl` is a LOCAL FILE
/// path and MUST load via [Image.file] — loading it with a `NetworkImage` fails
/// and leaves a blank/black circle (the bug this widget replaces). In **Cloud
/// mode** it's a network URL. Both fall back to the bundled default avatar when
/// the source is null or fails to load.
class ProfileAvatarImage extends StatelessWidget {
  final String? avatarUrl;
  final bool isPrivate;

  const ProfileAvatarImage({
    super.key,
    required this.avatarUrl,
    required this.isPrivate,
  });

  static Widget _fallback() =>
      Image.asset('assets/images/default_avatar.png', fit: BoxFit.cover);

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl;
    if (url == null) return _fallback();
    if (isPrivate) {
      return Image.file(
        File(url),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _fallback(),
    );
  }
}

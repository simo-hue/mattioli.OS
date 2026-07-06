// Guards the fix for the "profile photo goes black on other pages" bug: the
// avatar must load a Private-mode `avatarUrl` (a LOCAL FILE path) via FileImage,
// NOT NetworkImage (which fails and leaves a blank/black circle). Centralized in
// ProfileAvatarImage so the dashboard header and profile screen can't diverge.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/ui/widgets/profile_avatar_image.dart';

void main() {
  Image avatarImage(WidgetTester tester) =>
      tester.widget<Image>(find.byType(Image).first);

  testWidgets('Private mode loads a local path via FileImage (not network)',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ProfileAvatarImage(
        avatarUrl: '/var/mobile/private_profile/avatar.jpg',
        isPrivate: true,
      ),
    ));
    final img = avatarImage(tester);
    expect(img.image, isA<FileImage>());
    expect(img.image, isNot(isA<NetworkImage>()));
    tester.takeException(); // ignore the async file-not-found load error
  });

  testWidgets('Cloud mode loads a URL via NetworkImage', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ProfileAvatarImage(
        avatarUrl: 'https://example.com/avatar.jpg',
        isPrivate: false,
      ),
    ));
    expect(avatarImage(tester).image, isA<NetworkImage>());
    tester.takeException();
  });

  testWidgets('A null avatar falls back to the bundled default asset',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ProfileAvatarImage(avatarUrl: null, isPrivate: true),
    ));
    expect(avatarImage(tester).image, isA<AssetImage>());
    tester.takeException();
  });
}

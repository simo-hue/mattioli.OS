// The stored avatar path must survive the container moving underneath it.
//
// `profiles.avatar_url` holds an absolute path built from the app container at
// save time, and iOS regenerates that container's UUID across reinstalls. The
// stored string then points nowhere while the image is still on disk — which
// rendered the (black) default avatar, and then made the next sync push a
// tombstone that deleted the picture everywhere.
import 'package:evolve_sync/evolve_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const oldContainer =
      '/var/mobile/Containers/Data/Application/OLD-UUID/Library/Application Support';
  const newContainer =
      '/var/mobile/Containers/Data/Application/NEW-UUID/Library/Application Support';

  test('a path from a PREVIOUS container resolves into the current one', () {
    final candidates = avatarPathCandidates(
      stored: '$oldContainer/private_profile/avatar.png',
      supportDir: newContainer,
    );

    expect(candidates.first, '$newContainer/private_profile/avatar.png',
        reason: 'the image did not move — only the container prefix did');
  });

  test('the literal stored path is still tried, as a fallback', () {
    const stored = '/somewhere/else/avatar.png';
    final candidates = avatarPathCandidates(
      stored: stored,
      supportDir: newContainer,
    );

    expect(candidates, contains(stored));
    expect(candidates.indexOf(stored), greaterThan(0),
        reason: 'the container-relative candidate must be preferred');
  });

  test('a path already inside the current container is offered once', () {
    const stored = '$newContainer/private_profile/avatar.png';
    final candidates = avatarPathCandidates(
      stored: stored,
      supportDir: newContainer,
    );

    expect(candidates, [stored], reason: 'idempotent — no duplicate probe');
  });

  test('a bare filename is never resolved as a RELATIVE path', () {
    // Resolving it relatively would hit the process working directory, which on
    // a device is not the app container at all.
    final candidates = avatarPathCandidates(
      stored: 'avatar.png',
      supportDir: newContainer,
    );

    expect(candidates, ['$newContainer/private_profile/avatar.png']);
    expect(candidates, isNot(contains('avatar.png')));
  });

  test('the pulled-avatar filename shape resolves too', () {
    // applyPulledAvatar writes `avatar_sync_<millis>.img`.
    final candidates = avatarPathCandidates(
      stored: '$oldContainer/private_profile/avatar_sync_1750000000000.img',
      supportDir: newContainer,
    );

    expect(candidates.first,
        '$newContainer/private_profile/avatar_sync_1750000000000.img');
  });

  test('an empty or blank stored value yields nothing to probe', () {
    expect(avatarPathCandidates(stored: '', supportDir: newContainer), isEmpty);
    expect(
        avatarPathCandidates(stored: '   ', supportDir: newContainer), isEmpty);
  });

  test('a trailing separator on the support dir does not double up', () {
    final candidates = avatarPathCandidates(
      stored: 'avatar.png',
      supportDir: '$newContainer/',
    );

    expect(candidates.first, '$newContainer/private_profile/avatar.png');
  });

  test('a Windows-style separator is not mistaken for part of the filename', () {
    // A restored backup can carry a path written by another platform.
    final candidates = avatarPathCandidates(
      stored: r'C:\Users\simo\AppData\private_profile\avatar.png',
      supportDir: newContainer,
    );

    expect(candidates.first, '$newContainer/private_profile/avatar.png');
  });
}

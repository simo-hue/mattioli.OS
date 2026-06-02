import 'dart:io';

class DesktopSystemSettingsService {
  const DesktopSystemSettingsService._();

  static Future<void> openPermissions() async {
    if (Platform.isMacOS) {
      await Process.run('open', [
        'x-apple.systempreferences:com.apple.preference.security',
      ]);
      return;
    }
    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', 'ms-settings:notifications']);
      return;
    }
    await Process.run('xdg-open', ['settings://']);
  }
}

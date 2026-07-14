/// Privacy protection / data sanitization utilities.
///
/// Ported verbatim (same regexes + key list) from the mobile client's
/// `PrivacyUtils` so both apps redact the same secrets before anything leaves
/// the device (Sentry breadcrumbs / messages / contexts). Kept duplicated rather
/// than shared, matching the codebase's existing convention for cross-client
/// logic (`streak_utils`, `import_merge`, `macro_goal_calendar`).
class PrivacyUtils {
  /// Removes sensitive patterns from a string (emails, JWTs, secret key/values).
  static String sanitizeString(String? text) {
    if (text == null || text.isEmpty) return '';

    String sanitized = text;

    // Emails.
    final emailRegex = RegExp(
      r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
    );
    sanitized = sanitized.replaceAll(emailRegex, '[EMAIL_REDACTED]');

    // JWTs (Supabase tokens).
    final jwtRegex = RegExp(
      r'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+',
    );
    sanitized = sanitized.replaceAll(jwtRegex, '[JWT_REDACTED]');

    // Sensitive keys in JSON or key=value strings.
    final sensitiveKeysRegex = RegExp(
      r'(password|token|secret|access_token|refresh_token|authorization)["\s]*[:=]["\s]*([^"\s,}]*)',
      caseSensitive: false,
    );
    sanitized = sanitized.replaceAllMapped(sensitiveKeysRegex, (match) {
      final key = match.group(1);
      return '$key: "[REDACTED]"';
    });

    return sanitized;
  }

  /// Recursively sanitizes a data map, redacting values under sensitive keys.
  static Map<String, dynamic>? sanitizeMap(Map<String, dynamic>? map) {
    if (map == null) return null;

    final sanitizedMap = Map<String, dynamic>.from(map);
    const sensitiveKeys = [
      'email',
      'password',
      'token',
      'secret',
      'authorization',
      'access_token',
      'refresh_token',
    ];

    for (final key in sanitizedMap.keys) {
      if (sensitiveKeys.any((sk) => key.toLowerCase().contains(sk))) {
        sanitizedMap[key] = '[REDACTED]';
      } else if (sanitizedMap[key] is String) {
        sanitizedMap[key] = sanitizeString(sanitizedMap[key] as String);
      } else if (sanitizedMap[key] is Map<String, dynamic>) {
        sanitizedMap[key] = sanitizeMap(sanitizedMap[key] as Map<String, dynamic>);
      } else if (sanitizedMap[key] is List) {
        sanitizedMap[key] = (sanitizedMap[key] as List).map((item) {
          if (item is String) return sanitizeString(item);
          if (item is Map<String, dynamic>) return sanitizeMap(item);
          return item;
        }).toList();
      }
    }

    return sanitizedMap;
  }
}

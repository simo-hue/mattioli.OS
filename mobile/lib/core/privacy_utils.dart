/// Utility per la protezione della privacy e la sanitizzazione dei dati.
class PrivacyUtils {
  /// Rimuove pattern sensibili da una stringa (Email, JWT, chiavi segrete).
  static String sanitizeString(String? text) {
    if (text == null || text.isEmpty) return '';

    String sanitized = text;

    // Pattern per Email
    final emailRegex = RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}');
    sanitized = sanitized.replaceAll(emailRegex, '[EMAIL_REDACTED]');

    // Pattern per JWT (Supabase token)
    final jwtRegex = RegExp(r'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+');
    sanitized = sanitized.replaceAll(jwtRegex, '[JWT_REDACTED]');

    // Pattern per chiavi sensibili in JSON o stringhe chiave=valore
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

  /// Sanitizza ricorsivamente una mappa di dati rimuovendo valori per chiavi sensibili.
  static Map<String, dynamic>? sanitizeMap(Map<String, dynamic>? map) {
    if (map == null) return null;

    final sanitizedMap = Map<String, dynamic>.from(map);
    final sensitiveKeys = ['email', 'password', 'token', 'secret', 'authorization', 'access_token', 'refresh_token'];

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

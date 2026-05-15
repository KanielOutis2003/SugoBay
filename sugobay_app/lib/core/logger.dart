import 'dart:developer' as dev;

/// Structured logger for SugoBay. Replaces raw print() calls.
/// In production, this can be extended to send logs to a remote service.
class Log {
  static void info(String message, {String? tag}) {
    _log('INFO', message, tag: tag);
  }

  static void warn(String message, {String? tag}) {
    _log('WARN', message, tag: tag);
  }

  static void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log('ERROR', message, tag: tag);
    if (error != null) {
      dev.log('  error: $error', name: tag ?? 'SugoBay');
    }
    if (stackTrace != null) {
      dev.log('  stack: $stackTrace', name: tag ?? 'SugoBay');
    }
  }

  static void _log(String level, String message, {String? tag}) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    dev.log('[$timestamp] $level: $message', name: tag ?? 'SugoBay');
  }
}

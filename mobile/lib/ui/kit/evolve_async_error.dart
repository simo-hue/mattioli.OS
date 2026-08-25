import 'package:flutter/material.dart';

import '../../core/app_logger.dart';
import '../../core/theme.dart';
import '../../i18n/translations.g.dart';

/// The error state for a failed async provider, on any surface a user sees.
///
/// Exists because the statistics tabs each rendered
/// `Text('${t.common.status.error}: $err')` — a Riverpod `AsyncValue` error
/// object interpolated straight into user-facing copy, in seventeen places. In
/// practice that is a PostgREST body: table names, constraint names, and a
/// sentence of English shown to someone reading the app in Arabic. The same
/// SEC-7 / I18N-3 rule the global error handler already follows.
///
/// The error is not discarded, which is why this is a widget rather than a
/// deleted string. Those seventeen sites had no logging of their own and there
/// is no `ProviderObserver` collecting provider failures either — so simply
/// dropping `$err` would have made the statistics tabs fail *silently*, trading
/// a privacy leak for a debugging blind spot. This logs it and shows the label.
///
/// Stateful so the log fires ONCE when the error appears, not on every rebuild:
/// these sit inside tab views that rebuild on scroll, animation and theme
/// changes, and a `build()`-time log would flood the app-log ring buffer that
/// `app_logs_screen.dart` shows the user.
///
/// And logged from a POST-FRAME callback, not straight out of `initState`.
/// `AppLogger._addEntry` notifies its listeners synchronously, and
/// `app_logs_screen.dart` registers one that calls `setState` — so logging
/// during the build phase throws "setState() called during build" whenever the
/// user happens to have the log viewer open behind a statistics tab. Asserts are
/// stripped in release, so that particular hazard is debug-only; deferring one
/// frame costs nothing and removes it in every build mode.
class EvolveAsyncError extends StatefulWidget {
  const EvolveAsyncError({
    super.key,
    required this.error,
    this.stackTrace,
    this.context,
  });

  /// The `AsyncValue` error object. Logged, never rendered.
  final Object error;
  final StackTrace? stackTrace;

  /// What was being loaded, for the log line — e.g. `'[Stats] habit overview'`.
  /// The label the user sees is the same either way.
  final String? context;

  @override
  State<EvolveAsyncError> createState() => _EvolveAsyncErrorState();
}

class _EvolveAsyncErrorState extends State<EvolveAsyncError> {
  @override
  void initState() {
    super.initState();
    _logAfterFrame();
  }

  @override
  void didUpdateWidget(EvolveAsyncError oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A DIFFERENT failure in the same slot is a different event. Comparing the
    // objects rather than re-logging unconditionally keeps a rebuild that
    // carries the same error quiet.
    if (widget.error != oldWidget.error) _logAfterFrame();
  }

  /// See the class doc: the listener chain reaches a `setState`, so this must
  /// not run inside the build phase.
  void _logAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _log();
    });
  }

  void _log() {
    AppLogger.error(
      widget.context ?? '[UI] Async provider failed',
      widget.error,
      widget.stackTrace,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      context.t.common.status.error,
      style: TextStyle(color: context.appColors.mutedForeground),
    );
  }
}

import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../core/verification_config.dart';
import '../../core/verification_providers.dart';
import '../../i18n/translations.g.dart';

/// The Apple Health disclosure, opened from Settings.
///
/// This exists because of Guideline 2.5.1: "The app uses the HealthKit or
/// CareKit APIs but does not clearly identify the HealthKit and CareKit
/// functionality in the app's user interface." It was a fair rejection. The only
/// mention of Health anywhere in the app was a button three levels deep inside
/// the habit-creation modal, behind an Auto-verify switch that defaults off —
/// and that button hides itself permanently once tapped, so identification
/// could evaporate and never come back.
///
/// So this surface is reachable in two taps from launch, never hides, and does
/// not depend on the user having created a single habit. Apple asked for "a
/// screen recording showing where this identification can be found"; this is the
/// thing to record.
///
/// Naming follows the HealthKit HIG rather than our own instincts:
/// - "Refer to the Health app as Apple Health" — but "Use the system-provided
///   translation of Health", so the name comes from i18n (`t.health.appName`)
///   and differs per locale: Apple Health / Salute / Salud / Apple Health / صحتي.
///   It is never built as "Apple " + a translated word; there is no "Apple
///   Salute".
/// - "Don't use the term HealthKit. HealthKit is a developer-facing term." The
///   string does not appear in any locale.
class AppleHealthForm extends ConsumerWidget {
  const AppleHealthForm({super.key});

  /// The HealthKit metrics we read, in catalog order. Derived from the same
  /// catalog the habit editor offers, so this list cannot drift out of sync with
  /// what the app actually asks for.
  static List<VerificationTemplate> get readTemplates => [
    for (final t in VerificationCatalog.all)
      if (t.isHealthKit) t,
  ];

  /// Apple sample identifiers for every HealthKit metric we can read.
  static Set<String> get _allTypeIds => {
    for (final t in readTemplates)
      if (t.healthKitTypeIdentifier != null) t.healthKitTypeIdentifier!,
  };

  Future<void> _requestAll(WidgetRef ref) async {
    ref.hapticMedium();
    final ids = _allTypeIds;
    await ref.read(healthKitBridgeProvider).requestAuthorization(ids);
    // iOS never reports whether read access was granted, so "the sheet was
    // shown" is the only terminal state we can honestly record. Mark every type
    // so the habit editor stops offering its own per-metric prompt too.
    final notifier = ref.read(healthAuthRequestedTypesProvider.notifier);
    for (final id in ids) {
      await notifier.markRequested(id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final t = context.t.health;
    final app = t.appName;
    final available = ref.watch(healthDataAvailableProvider);
    final requested = ref.watch(healthAuthRequestedTypesProvider);
    final askedForAll = _allTypeIds.every(requested.contains);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.worksWith(app: app),
            style: TextStyle(fontFamily: 'Inter', 
              fontSize: 13,
              height: 1.45,
              color: colors.mutedForeground,
            ),
          ),

          // The iPad case. Every metric below is recorded by an iPhone or a
          // Watch, so on a device without one they all read empty and the
          // feature looks broken rather than inapplicable. The reviewer who
          // rejected us was on an iPad Air.
          available.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (isAvailable) => isAvailable
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _Notice(
                      icon: LucideIcons.info,
                      text: VerificationConfig.healthKitEnabled
                          ? t.noData(app: app)
                          : t.unavailableOnDevice(app: app),
                    ),
                  ),
          ),

          const SizedBox(height: 20),
          Text(
            t.readsTitle,
            style: TextStyle(fontFamily: 'Inter', 
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: colors.foreground,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            t.readsBody,
            style: TextStyle(fontFamily: 'Inter', 
              fontSize: 13,
              height: 1.45,
              color: colors.mutedForeground,
            ),
          ),
          const SizedBox(height: 10),
          for (final template in readTemplates)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(LucideIcons.dot, size: 16, color: colors.mutedForeground),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _templateLabel(context, template),
                      style: TextStyle(fontFamily: 'Inter', 
                        fontSize: 13,
                        color: colors.foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),
          _Notice(icon: LucideIcons.lock, text: t.readOnly(app: app)),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _requestAll(ref),
              child: Text(t.allowAccess),
            ),
          ),

          // Only worth saying once the prompt has been through: before that,
          // "we can't tell you whether it worked" is noise.
          if (askedForAll) ...[
            const SizedBox(height: 12),
            Text(
              t.grantNote(app: app),
              style: TextStyle(fontFamily: 'Inter', 
                fontSize: 12,
                height: 1.45,
                color: colors.mutedForeground,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            t.manageHint(app: app),
            style: TextStyle(fontFamily: 'Inter', 
              fontSize: 12,
              height: 1.45,
              color: colors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

/// The habit editor's label for a metric, reused so the two lists always agree.
String _templateLabel(BuildContext context, VerificationTemplate template) {
  final labels = context.t.verification.templates;
  return switch (template.key) {
    'steps' => labels.steps,
    'exercise_minutes' => labels.exerciseMinutes,
    'active_energy' => labels.activeEnergy,
    'stand_hours' => labels.standHours,
    'distance' => labels.distance,
    'mindful_minutes' => labels.mindfulMinutes,
    'sleep_hours' => labels.sleepHours,
    'workout' => labels.workout,
    _ => template.key,
  };
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: colors.mutedForeground),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontFamily: 'Inter', 
                fontSize: 12.5,
                height: 1.4,
                color: colors.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

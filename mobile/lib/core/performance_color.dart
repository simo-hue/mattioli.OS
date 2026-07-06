/// Shared "performance" color scale used across the calendar surfaces (home
/// monthly view day cells, yearly view month bars) so they can't drift apart.
///
/// A day's completion ratio (`done / habits-active-that-day`, 0..1) maps to a
/// hue swept from RED (0% completed) through yellow to GREEN (100% completed).
/// Callers pick the saturation / lightness / alpha that suits their surface
/// (a faint tinted cell background vs. a solid bar).
library;

import 'package:flutter/material.dart';

/// Hue in degrees for a completion ratio: 0.0 → 0° (red), 1.0 → 142° (green).
double performanceHue(double completionPct) => completionPct.clamp(0.0, 1.0) * 142.0;

/// A performance color for [completionPct]. Defaults render a solid, legible
/// bar; pass low [lightness] + [alpha] for a subtle background tint.
///
/// Alpha is applied via [Color.withValues] (not baked into the HSL alpha) so
/// the result is byte-identical to the hand-written cell colors this replaced.
Color performanceColor(
  double completionPct, {
  double saturation = 0.7,
  double lightness = 0.5,
  double alpha = 1.0,
}) =>
    HSLColor.fromAHSL(
      1.0,
      performanceHue(completionPct),
      saturation,
      lightness,
    ).toColor().withValues(alpha: alpha);

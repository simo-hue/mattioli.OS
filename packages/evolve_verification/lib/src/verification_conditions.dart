import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'verification_provider.dart';
import 'verification_rule.dart';

/// The maximum number of conditions a compound verifiable habit may combine
/// (Q3). One named constant so raising it later is a one-line change.
const int kMaxVerificationConditions = 3;

/// The envelope version persisted inside the JSON, so the shape can evolve
/// without another column.
const int kVerifyConditionsVersion = 1;

/// The parsed contents of a `goals.verify_conditions` column: an ordered list of
/// 2..[kMaxVerificationConditions] conditions and the operator that joins them
/// (Q4). A one-condition rule is NEVER stored here — it uses the flat `verify_*`
/// columns — so this type only ever represents a genuinely compound habit.
@immutable
class VerificationConditions {
  final List<VerificationRule> conditions;
  final VerificationJoin op;

  const VerificationConditions({required this.conditions, required this.op});

  int get length => conditions.length;

  @override
  bool operator ==(Object other) =>
      other is VerificationConditions &&
      other.op == op &&
      listEquals(other.conditions, conditions);

  @override
  int get hashCode => Object.hash(op, Object.hashAll(conditions));

  @override
  String toString() =>
      'VerificationConditions(${op.wireName}, $conditions)';
}

/// Encodes [conditions] + [op] into the JSON string stored in
/// `goals.verify_conditions`, or **null** when there is nothing compound to
/// store (fewer than 2 conditions — those live in the flat `verify_*` columns).
/// Defensively clamped to [kMaxVerificationConditions]; the creation UI already
/// enforces the cap, so this never truncates in practice.
String? encodeVerifyConditions(
  List<VerificationRule> conditions,
  VerificationJoin op,
) {
  if (conditions.length < 2) return null;
  final capped = conditions.take(kMaxVerificationConditions).toList();
  return jsonEncode({
    'v': kVerifyConditionsVersion,
    'op': op.wireName,
    'conditions': [for (final c in capped) c.toWire()],
  });
}

/// Decodes a `goals.verify_conditions` value (a JSON string, or an already
/// decoded Map), or **null** when it is absent, blank, malformed, describes
/// fewer than 2 valid conditions, or has MORE than [kMaxVerificationConditions]
/// (a newer client's wider set we can't faithfully represent — better to fall
/// back to "not compound" than to silently drop a condition and change the
/// verdict). Never throws: a bad blob is "not compound", never a half-rule.
VerificationConditions? decodeVerifyConditions(Object? raw) {
  if (raw == null) return null;
  try {
    Map<String, Object?> map;
    if (raw is String) {
      if (raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      map = decoded.cast<String, Object?>();
    } else if (raw is Map) {
      map = raw.cast<String, Object?>();
    } else {
      return null;
    }

    // Type-safe read: a wrong-typed `op` (number/bool/object from a corrupted or
    // foreign blob) must degrade to null, not throw.
    final opRaw = map['op'];
    final op = opRaw is String ? VerificationJoin.fromWire(opRaw) : null;
    final rawConds = map['conditions'];
    if (op == null || rawConds is! List) return null;

    final conditions = <VerificationRule>[];
    for (final c in rawConds) {
      final rule = VerificationRule.fromWire(c);
      if (rule == null) return null; // any invalid condition ⇒ reject the whole set
      conditions.add(rule);
    }
    if (conditions.length < 2 || conditions.length > kMaxVerificationConditions) {
      return null;
    }
    return VerificationConditions(conditions: conditions, op: op);
  } catch (_) {
    // A corrupted / foreign blob is "not compound", never a throw — this read
    // runs inside an eager goal-row map that a single throw would take down.
    return null;
  }
}

/// The complete set of `goals` verification columns (the flat `verify_*` five
/// PLUS `verify_conditions`) for a habit whose verification is [conditions]
/// joined by [op] (Q4). For a store that writes every column explicitly (e.g.
/// SQLite `ConflictAlgorithm.replace`):
///
/// - **empty** (manual habit) ⇒ all six columns null;
/// - **one** condition (single rule) ⇒ the flat `verify_*` columns, `verify_conditions` null;
/// - **two+** conditions (compound) ⇒ `verify_conditions` JSON, flat columns NULLED
///   so a pre-compound client reads the habit as *manual* and can never mis-verify it.
///
/// Does NOT include `verify_effective_from` (the D10 anchor is orthogonal to the
/// rule's content and is written by the model separately).
Map<String, Object?> verificationColumnsFor(
  List<VerificationRule> conditions, [
  VerificationJoin op = VerificationJoin.or,
]) {
  if (conditions.isEmpty) {
    return {...VerificationRule.nullColumns, 'verify_conditions': null};
  }
  if (conditions.length == 1) {
    return {...conditions.first.toColumns(), 'verify_conditions': null};
  }
  return {
    ...VerificationRule.nullColumns,
    'verify_conditions': encodeVerifyConditions(conditions, op),
  };
}

/// Reads the verification state out of a `goals` row map: the ordered conditions
/// and their operator, or **null** for a manual habit. Read precedence (Q4):
/// `verify_conditions` (compound) wins if present and valid; else the flat
/// `verify_*` columns (a single rule); else null. A single rule comes back as a
/// one-element list with the harmless [VerificationJoin.or].
VerificationConditions? readVerificationColumns(Map<String, Object?> row) {
  final compound = decodeVerifyConditions(row['verify_conditions']);
  if (compound != null) return compound;
  final single = VerificationRule.fromColumns(row);
  if (single != null) {
    return VerificationConditions(conditions: [single], op: VerificationJoin.or);
  }
  return null;
}

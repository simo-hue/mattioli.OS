import '../day_verdict.dart';
import '../verification_log_writer.dart';

/// One recorded [VerificationLogWriter.writeVerdict] call.
class RecordedVerdict {
  final String goalId;
  final DateTime day;
  final VerificationOutcome outcome;
  final double? value;
  const RecordedVerdict(this.goalId, this.day, this.outcome, this.value);

  @override
  String toString() => 'RecordedVerdict($goalId, $day, ${outcome.name}, $value)';
}

/// In-memory [VerificationLogWriter] for tests — records every verdict written.
class FakeVerificationLogWriter implements VerificationLogWriter {
  final List<RecordedVerdict> writes = [];

  @override
  Future<void> writeVerdict({
    required String goalId,
    required DateTime day,
    required VerificationOutcome outcome,
    double? value,
  }) async {
    writes.add(RecordedVerdict(goalId, day, outcome, value));
  }
}

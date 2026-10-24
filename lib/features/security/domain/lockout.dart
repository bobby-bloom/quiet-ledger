import 'dart:math';

import 'package:meta/meta.dart';

/// Escalating delay after repeated wrong PIN/password entries.
///
/// The first [freeAttempts] failures carry no delay. Each further failure
/// waits [baseDelay] × 2^(failures − freeAttempts), capped at [maxDelay].
@immutable
class LockoutPolicy {
  const LockoutPolicy({
    this.freeAttempts = 5,
    this.baseDelay = const Duration(seconds: 30),
    this.maxDelay = const Duration(hours: 1),
  });

  final int freeAttempts;
  final Duration baseDelay;
  final Duration maxDelay;

  /// Delay imposed after the [failures]-th consecutive failure.
  Duration delayAfter(int failures) {
    if (failures < freeAttempts) return Duration.zero;
    final exp = min(failures - freeAttempts, 20);
    final ms = baseDelay.inMilliseconds * pow(2, exp);
    return Duration(milliseconds: min(ms.toInt(), maxDelay.inMilliseconds));
  }
}

/// Persisted failure counter.
@immutable
class AttemptState {
  const AttemptState({this.failures = 0, this.lockedUntil});

  factory AttemptState.fromJson(Map<String, Object?> json) {
    final until = json['lockedUntil'] as int?;
    return AttemptState(
      failures: json['failures'] as int? ?? 0,
      lockedUntil: until == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(until, isUtc: true),
    );
  }

  static const initial = AttemptState();

  final int failures;
  final DateTime? lockedUntil;

  Map<String, Object?> toJson() => {
    'failures': failures,
    if (lockedUntil != null) 'lockedUntil': lockedUntil!.millisecondsSinceEpoch,
  };

  @override
  bool operator ==(Object other) =>
      other is AttemptState &&
      other.failures == failures &&
      other.lockedUntil == lockedUntil;

  @override
  int get hashCode => Object.hash(failures, lockedUntil);
}

/// Applies a [LockoutPolicy] to an [AttemptState] using an injectable clock.
class AttemptTracker {
  AttemptTracker({
    required this.now,
    this.policy = const LockoutPolicy(),
    AttemptState initial = AttemptState.initial,
  }) : _state = initial;

  final LockoutPolicy policy;
  final DateTime Function() now;
  AttemptState _state;

  AttemptState get state => _state;

  int get failures => _state.failures;

  /// Time left until the next attempt is allowed (zero when allowed now).
  Duration get remaining {
    final until = _state.lockedUntil;
    if (until == null) return Duration.zero;
    final left = until.difference(now().toUtc());
    return left.isNegative ? Duration.zero : left;
  }

  bool get canAttempt => remaining == Duration.zero;

  /// Records a wrong entry and returns the new state.
  AttemptState recordFailure() {
    final failures = _state.failures + 1;
    final delay = policy.delayAfter(failures);
    return _state = AttemptState(
      failures: failures,
      lockedUntil: delay == Duration.zero ? null : now().toUtc().add(delay),
    );
  }

  /// Resets the counter after a successful unlock.
  AttemptState recordSuccess() => _state = AttemptState.initial;
}

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/security/domain/lockout.dart';

void main() {
  test('policy: free attempts, then doubling delay, capped', () {
    const p = LockoutPolicy();
    for (var i = 0; i < 5; i++) {
      expect(p.delayAfter(i), Duration.zero);
    }
    expect(p.delayAfter(5), const Duration(seconds: 30));
    expect(p.delayAfter(6), const Duration(seconds: 60));
    expect(p.delayAfter(7), const Duration(minutes: 2));
    expect(p.delayAfter(12), const Duration(hours: 1));
    expect(p.delayAfter(100), const Duration(hours: 1));
  });

  test('tracker uses the injected clock', () {
    var now = DateTime.utc(2026, 10, 23, 12);
    final t = AttemptTracker(now: () => now);
    for (var i = 0; i < 4; i++) {
      t.recordFailure();
      expect(t.canAttempt, isTrue);
    }
    final s = t.recordFailure();
    expect(s.failures, 5);
    expect(t.canAttempt, isFalse);
    expect(t.remaining, const Duration(seconds: 30));

    now = now.add(const Duration(seconds: 29));
    expect(t.remaining, const Duration(seconds: 1));
    now = now.add(const Duration(seconds: 1));
    expect(t.canAttempt, isTrue);

    t.recordFailure();
    expect(t.remaining, const Duration(seconds: 60));

    t.recordSuccess();
    expect(t.failures, 0);
    expect(t.canAttempt, isTrue);
  });

  test('state survives JSON (persisted in secure storage)', () {
    final s = AttemptState(
      failures: 6,
      lockedUntil: DateTime.utc(2026, 10, 23, 12, 1),
    );
    expect(AttemptState.fromJson(s.toJson()), s);
    expect(
      AttemptState.fromJson(AttemptState.initial.toJson()),
      AttemptState.initial,
    );
  });
}

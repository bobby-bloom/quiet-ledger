import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/sync/hlc.dart';

void main() {
  test('tick is monotonic even when the wall clock goes backwards', () {
    var now = 1000;
    final clock = HlcClock('a', now: () => now);
    final a = clock.tick();
    now = 900;
    final b = clock.tick();
    expect(b > a, isTrue);
    expect(b.millis, 1000);
    expect(b.counter, 1);
  });

  test('string form sorts like the logical time', () {
    const x = Hlc(5, 2, 'n');
    const y = Hlc(5, 10, 'n');
    const z = Hlc(10, 0, 'n');
    final strings = [z, y, x].map((h) => h.toString()).toList()..sort();
    expect(strings, [x.toString(), y.toString(), z.toString()]);
    expect(Hlc.parse(y.toString()), y);
  });

  test('receive moves past the remote timestamp', () {
    final clock = HlcClock('a', now: () => 1000);
    final r = clock.receive(const Hlc(1000, 7, 'b'));
    expect(r.millis, 1000);
    expect(r.counter, 8);
    expect(r.nodeId, 'a');
  });

  test('receive rejects excessive drift', () {
    final clock = HlcClock('a', now: () => 0);
    expect(
      () => clock.receive(const Hlc(10 * 60 * 1000, 0, 'b')),
      throwsA(isA<ClockDriftException>()),
    );
  });

  test('node id with dashes parses', () {
    const h = Hlc(1, 1, '0192-abcd-ef');
    expect(Hlc.parse(h.toString()), h);
  });
}

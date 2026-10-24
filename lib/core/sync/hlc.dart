import 'dart:math' as math;

import 'package:meta/meta.dart';

/// Hybrid logical clock timestamp.
///
/// Serialised as `<millis:15>-<counter:5 base36>-<nodeId>` so that the string
/// form sorts lexicographically in the same order as the logical time. This
/// lets the DB compare HLCs with plain text comparison.
@immutable
class Hlc implements Comparable<Hlc> {
  const Hlc(this.millis, this.counter, this.nodeId);

  factory Hlc.zero(String nodeId) => Hlc(0, 0, nodeId);

  factory Hlc.parse(String value) {
    final first = value.indexOf('-');
    final second = value.indexOf('-', first + 1);
    if (first < 0 || second < 0) {
      throw FormatException('Invalid HLC', value);
    }
    return Hlc(
      int.parse(value.substring(0, first)),
      int.parse(value.substring(first + 1, second), radix: 36),
      value.substring(second + 1),
    );
  }

  static const maxCounter = 0xFFFF;

  /// Maximum tolerated clock drift of a remote timestamp.
  static const maxDrift = Duration(minutes: 1);

  final int millis;
  final int counter;
  final String nodeId;

  @override
  int compareTo(Hlc other) {
    final m = millis.compareTo(other.millis);
    if (m != 0) return m;
    final c = counter.compareTo(other.counter);
    if (c != 0) return c;
    return nodeId.compareTo(other.nodeId);
  }

  bool operator <(Hlc other) => compareTo(other) < 0;
  bool operator >(Hlc other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) =>
      other is Hlc &&
      other.millis == millis &&
      other.counter == counter &&
      other.nodeId == nodeId;

  @override
  int get hashCode => Object.hash(millis, counter, nodeId);

  @override
  String toString() =>
      '${millis.toString().padLeft(15, '0')}-'
      '${counter.toRadixString(36).padLeft(5, '0')}-$nodeId';
}

/// Thrown when a remote clock is too far ahead of the local one.
class ClockDriftException implements Exception {
  ClockDriftException(this.driftMillis);
  final int driftMillis;

  @override
  String toString() => 'ClockDriftException: remote is ${driftMillis}ms ahead';
}

/// Generates monotonically increasing [Hlc]s for one device.
class HlcClock {
  HlcClock(this.nodeId, {int Function()? now, Hlc? last})
    : _now = now ?? (() => DateTime.now().millisecondsSinceEpoch),
      _last = last ?? Hlc.zero(nodeId);

  final String nodeId;
  final int Function() _now;
  Hlc _last;

  Hlc get last => _last;

  /// Timestamp for a local event.
  Hlc tick() {
    final wall = _now();
    final millis = math.max(wall, _last.millis);
    final counter = millis == _last.millis ? _last.counter + 1 : 0;
    if (counter > Hlc.maxCounter) {
      // Counter overflow: advance logical time by one millisecond.
      _last = Hlc(millis + 1, 0, nodeId);
    } else {
      _last = Hlc(millis, counter, nodeId);
    }
    return _last;
  }

  /// Merges a remote timestamp (on receive) so local time stays ahead of it.
  Hlc receive(Hlc remote) {
    final wall = _now();
    if (remote.millis - wall > Hlc.maxDrift.inMilliseconds) {
      throw ClockDriftException(remote.millis - wall);
    }
    final millis = math.max(math.max(wall, _last.millis), remote.millis);
    int counter;
    if (millis == _last.millis && millis == remote.millis) {
      counter = math.max(_last.counter, remote.counter) + 1;
    } else if (millis == _last.millis) {
      counter = _last.counter + 1;
    } else if (millis == remote.millis) {
      counter = remote.counter + 1;
    } else {
      counter = 0;
    }
    return _last = Hlc(millis, counter, nodeId);
  }
}

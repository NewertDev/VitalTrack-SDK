import 'dart:typed_data';

/// A VitalTrack EEG board found by [VitalTrackEeg.scan].
class EegBoard {
  const EegBoard({required this.id, required this.name, this.rssi});

  /// Platform identifier used to connect (MAC address or system UUID).
  final String id;

  /// Advertised name, for example `VitalTrack EEG (C2F5)`.
  final String name;

  /// Signal strength in dBm when the platform reports it.
  final int? rssi;

  @override
  String toString() => 'EegBoard($name, $id, rssi: $rssi)';
}

/// What a connected board reported about itself.
class EegBoardInfo {
  const EegBoardInfo({
    required this.firmwareVersion,
    required this.sampleRateHz,
    required this.channelCount,
    required this.motionAvailable,
  });

  final String firmwareVersion;

  /// EEG samples per second per channel (250).
  final int sampleRateHz;

  /// Number of EEG inputs (8), numbered 1 to [channelCount].
  final int channelCount;

  /// The board has a working motion sensor (accelerometer + gyroscope).
  final bool motionAvailable;
}

/// One EEG sample of every channel, already cleaned (filtered and
/// re-referenced). Channels not in use read 0.
class EegSample {
  const EegSample({
    required this.index,
    required this.microvolts,
    required this.filled,
    required this.restart,
  });

  /// Position in the stream since [EegConnection.start], 0-based. At 250
  /// samples per second, `index / 250` is the time in seconds.
  final int index;

  /// Clean EEG in microvolts, channel 1 at position 0.
  final Float32List microvolts;

  /// The board's sample was lost on the radio link and this one was filled
  /// in from its neighbours.
  final bool filled;

  /// First sample after a break in the stream (see [StreamNotice]).
  final bool restart;

  double channel(int number) => microvolts[number - 1];
}

/// Electrode contact, judged once a second from the signal itself (not an
/// impedance measurement).
enum ContactState {
  /// The channel is not in use.
  unused,

  /// Not judged yet, or the last second had missing data.
  waiting,

  /// 정상: attached, low noise.
  good,

  /// 약함: attached, but noisy.
  weak,

  /// 부착 안됨: not on the skin.
  detached,
}

/// The five classic bands, as shares of their sum.
enum EegBand { delta, theta, alpha, beta, gamma }

/// Relative band power of every channel over the last 8 seconds, updated
/// once a second.
class BandPowerUpdate {
  const BandPowerUpdate(this._percent);

  final Float32List _percent;

  /// Share of [band] on channel [number] (1-based) in percent, or null when
  /// not available (channel unused, not attached, or still warming up).
  double? percent(int number, EegBand band) {
    final value = _percent[(number - 1) * EegBand.values.length + band.index];
    return value.isNaN ? null : value;
  }
}

/// One motion-sensor sample, placed on the EEG timeline.
class MotionSample {
  const MotionSample({
    required this.position,
    required this.accelerationG,
    required this.rotationDps,
    required this.afterGap,
  });

  /// Fractional EEG sample index this motion sample was taken at.
  final double position;

  /// x, y, z acceleration in g (sensor axes).
  final Float32List accelerationG;

  /// x, y, z rotation rate in degrees per second (sensor axes).
  final Float32List rotationDps;

  /// Motion samples were lost just before this one.
  final bool afterGap;
}

enum PowerSource { battery, usbCharging, usbNotCharging, unknown }

class BatteryState {
  const BatteryState({this.percent, this.millivolts, required this.source});

  /// Estimated charge 0-100, null until measured.
  final int? percent;
  final int? millivolts;
  final PowerSource source;
}

enum StreamNoticeKind {
  /// Samples were lost on the link and filled in ([StreamNotice.count]).
  gapFilled,

  /// The stream broke for too long to fill; processing restarted.
  restarted,
}

class StreamNotice {
  const StreamNotice(this.kind, this.count);

  final StreamNoticeKind kind;

  /// Number of missing samples.
  final int count;
}

/// Result of [EegConnection.stop].
class StopResult {
  const StopResult({required this.sampleCount, required this.confirmed});

  /// Samples delivered in this stream, filled ones included.
  final int sampleCount;

  /// The board confirmed it had sent everything before stopping.
  final bool confirmed;
}

class StreamStats {
  const StreamStats({
    required this.samples,
    required this.filled,
    required this.restarts,
  });

  final int samples;
  final int filled;
  final int restarts;
}

enum EegConnectionState { connected, disconnected }

class VitalTrackException implements Exception {
  const VitalTrackException(this.message);

  final String message;

  @override
  String toString() => 'VitalTrackException: $message';
}

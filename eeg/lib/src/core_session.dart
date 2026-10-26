import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'models.dart';
import 'native.dart';

/// Kinds understood by the core's command and UUID functions.
abstract final class CoreCommand {
  static const int identify = 0;
  static const int setChannels = 1;
  static const int start = 2;
  static const int stop = 3;
}

abstract final class CoreUuid {
  static const int dataService = 0;
  static const int dataWrite = 1;
  static const int dataNotify = 2;
  static const int auxService = 3;
  static const int auxMotion = 4;
  static const int auxMotionInfo = 5;
  static const int auxPower = 6;
}

abstract final class CoreEventType {
  static const int identified = 1;
  static const int channels = 2;
  static const int stopped = 3;
  static const int contact = 4;
  static const int bandPower = 5;
  static const int power = 6;
  static const int motionInfo = 7;
  static const int gap = 8;
  static const int discontinuity = 9;
}

class CoreEvent {
  const CoreEvent(this.type, this.code, this.value1, this.value2);

  final int type;
  final int code;
  final int value1;
  final int value2;
}

/// Link-level facts the core knows and the Dart side must not hard-code.
class CoreLink {
  CoreLink._();

  static String uuid(int kind) {
    final library = CoreLibrary.instance;
    final buffer = calloc<Uint8>(64);
    try {
      final length = library.uuid(kind, buffer, 64);
      if (length <= 0) throw StateError('core has no UUID $kind');
      return String.fromCharCodes(buffer.asTypedList(length));
    } finally {
      calloc.free(buffer);
    }
  }

  static bool nameMatches(String name) {
    final library = CoreLibrary.instance;
    final bytes = name.codeUnits;
    final buffer = calloc<Uint8>(bytes.length + 1);
    try {
      buffer.asTypedList(bytes.length).setAll(0, bytes.map((c) => c & 0xFF));
      buffer[bytes.length] = 0;
      return library.nameMatches(buffer) == 1;
    } finally {
      calloc.free(buffer);
    }
  }

  static int get preferredMtu => CoreLibrary.instance.preferredMtu();

  static String get version {
    final v = CoreLibrary.instance.version();
    return '${(v >> 16) & 0xFF}.${(v >> 8) & 0xFF}.${v & 0xFF}';
  }
}

/// One native session: bytes in, clean data and events out.
class CoreSession {
  CoreSession() : _library = CoreLibrary.instance {
    _handle = _library.create();
    if (_handle == nullptr) throw StateError('core session not created');
  }

  static const int _sampleCapacity = 512;
  static const int _motionCapacity = 128;

  final CoreLibrary _library;
  late final Pointer<VtcSessionHandle> _handle;
  final Pointer<VtcSample> _samples = calloc<VtcSample>(_sampleCapacity);
  final Pointer<VtcMotionSample> _motion =
      calloc<VtcMotionSample>(_motionCapacity);
  final Pointer<VtcEvent> _event = calloc<VtcEvent>();
  final Pointer<Int32> _contact = calloc<Int32>(8);
  final Pointer<Float> _bands = calloc<Float>(40);
  final Pointer<Uint8> _command = calloc<Uint8>(16);
  Pointer<Uint8> _input = calloc<Uint8>(512);
  int _inputCapacity = 512;
  bool _disposed = false;

  Uint8List command(int kind, [int argument = 0]) {
    final length = _library.command(_handle, kind, argument, _command, 16);
    if (length < 0) throw StateError('command $kind not available');
    return Uint8List.fromList(_command.asTypedList(length));
  }

  void feedData(Uint8List bytes) => _feed(bytes, _library.feedData);
  void feedMotion(Uint8List bytes) => _feed(bytes, _library.feedMotion);
  void feedMotionInfo(Uint8List bytes) => _feed(bytes, _library.feedMotionInfo);
  void feedPower(Uint8List bytes) => _feed(bytes, _library.feedPower);

  void _feed(Uint8List bytes,
      void Function(Pointer<VtcSessionHandle>, Pointer<Uint8>, int) feed) {
    if (_disposed || bytes.isEmpty) return;
    if (bytes.length > _inputCapacity) {
      calloc.free(_input);
      _inputCapacity = bytes.length;
      _input = calloc<Uint8>(_inputCapacity);
    }
    _input.asTypedList(bytes.length).setAll(0, bytes);
    feed(_handle, _input, bytes.length);
  }

  List<CoreEvent> takeEvents() {
    final events = <CoreEvent>[];
    while (!_disposed && _library.nextEvent(_handle, _event) == 1) {
      final e = _event.ref;
      events.add(CoreEvent(e.type, e.code, e.value1, e.value2));
    }
    return events;
  }

  List<EegSample> takeSamples() {
    final out = <EegSample>[];
    while (!_disposed) {
      final n = _library.readSamples(_handle, _samples, _sampleCapacity);
      for (var i = 0; i < n; i++) {
        final s = _samples[i];
        final values = Float32List(8);
        for (var c = 0; c < 8; c++) {
          values[c] = s.microvolts[c];
        }
        out.add(EegSample(
          index: s.index,
          microvolts: values,
          filled: (s.flags & 1) != 0,
          restart: (s.flags & 2) != 0,
        ));
      }
      if (n < _sampleCapacity) break;
    }
    return out;
  }

  List<MotionSample> takeMotion() {
    final out = <MotionSample>[];
    while (!_disposed) {
      final n = _library.readMotion(_handle, _motion, _motionCapacity);
      for (var i = 0; i < n; i++) {
        final m = _motion[i];
        out.add(MotionSample(
          position: m.position,
          accelerationG: Float32List.fromList(
              [m.accelerationG[0], m.accelerationG[1], m.accelerationG[2]]),
          rotationDps: Float32List.fromList(
              [m.rotationDps[0], m.rotationDps[1], m.rotationDps[2]]),
          afterGap: (m.flags & 1) != 0,
        ));
      }
      if (n < _motionCapacity) break;
    }
    return out;
  }

  List<ContactState> contact() {
    _library.contact(_handle, _contact);
    return List<ContactState>.generate(8, (c) {
      final v = _contact[c];
      return v >= 0 && v < ContactState.values.length
          ? ContactState.values[v]
          : ContactState.waiting;
    }, growable: false);
  }

  BandPowerUpdate bandPower() {
    _library.bandPower(_handle, _bands);
    return BandPowerUpdate(Float32List.fromList(_bands.asTypedList(40)));
  }

  EegBoardInfo? boardInfo() {
    final device = calloc<VtcDevice>();
    try {
      if (_library.deviceInfo(_handle, device) != 1) return null;
      final d = device.ref;
      final firmware = <int>[];
      for (var i = 0; i < 24 && d.firmware[i] != 0; i++) {
        firmware.add(d.firmware[i]);
      }
      return EegBoardInfo(
        firmwareVersion: String.fromCharCodes(firmware),
        sampleRateHz: d.sampleRateHz,
        channelCount: d.channelCount,
        motionAvailable: _library.motionAvailable(_handle) == 1,
      );
    } finally {
      calloc.free(device);
    }
  }

  BatteryState battery() {
    final state = calloc<VtcPowerState>();
    try {
      _library.power(_handle, state);
      final s = state.ref;
      return BatteryState(
        percent: s.percent < 0 ? null : s.percent,
        millivolts: s.millivolts < 0 ? null : s.millivolts,
        source: switch (s.source) {
          0 => PowerSource.battery,
          1 => PowerSource.usbCharging,
          2 => PowerSource.usbNotCharging,
          _ => PowerSource.unknown,
        },
      );
    } finally {
      calloc.free(state);
    }
  }

  StreamStats stats() {
    final stats = calloc<VtcStats>();
    try {
      _library.stats(_handle, stats);
      final s = stats.ref;
      return StreamStats(
          samples: s.samples, filled: s.filled, restarts: s.discontinuities);
    } finally {
      calloc.free(stats);
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _library.destroy(_handle);
    calloc.free(_samples);
    calloc.free(_motion);
    calloc.free(_event);
    calloc.free(_contact);
    calloc.free(_bands);
    calloc.free(_command);
    calloc.free(_input);
  }
}

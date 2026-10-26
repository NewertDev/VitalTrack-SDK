// Bindings to the compiled VitalTrack core (vitaltrack_core.h).
import 'dart:ffi';
import 'dart:io';

final class VtcEvent extends Struct {
  @Int32()
  external int type;
  @Int32()
  external int code;
  @Int64()
  external int value1;
  @Int64()
  external int value2;
}

final class VtcSample extends Struct {
  @Uint64()
  external int index;
  @Uint32()
  external int flags;
  @Array(8)
  external Array<Float> microvolts;
}

final class VtcMotionSample extends Struct {
  @Double()
  external double position;
  @Array(3)
  external Array<Float> accelerationG;
  @Array(3)
  external Array<Float> rotationDps;
  @Uint32()
  external int flags;
}

final class VtcDevice extends Struct {
  @Int32()
  external int protocol;
  @Int32()
  external int sampleRateHz;
  @Int32()
  external int channelCount;
  @Uint32()
  external int channelMask;
  @Array(24)
  external Array<Uint8> firmware;
}

final class VtcPowerState extends Struct {
  @Int32()
  external int percent;
  @Int32()
  external int millivolts;
  @Int32()
  external int source;
}

final class VtcStats extends Struct {
  @Uint64()
  external int samples;
  @Uint64()
  external int filled;
  @Uint64()
  external int discontinuities;
  @Uint64()
  external int discardedBytes;
  @Uint64()
  external int droppedOutputs;
  @Uint32()
  external int boardDrops;
}

final class VtcSessionHandle extends Opaque {}

/// The library's functions, resolved once.
class CoreLibrary {
  CoreLibrary._(DynamicLibrary library)
      : version = library.lookupFunction<Uint32 Function(), int Function()>(
            'vtc_version'),
        uuid = library.lookupFunction<
            Int32 Function(Int32, Pointer<Uint8>, Int32),
            int Function(int, Pointer<Uint8>, int)>('vtc_uuid'),
        nameMatches = library.lookupFunction<Int32 Function(Pointer<Uint8>),
            int Function(Pointer<Uint8>)>('vtc_name_matches'),
        preferredMtu = library.lookupFunction<Int32 Function(), int Function()>(
            'vtc_preferred_mtu'),
        create = library.lookupFunction<Pointer<VtcSessionHandle> Function(),
            Pointer<VtcSessionHandle> Function()>('vtc_session_create'),
        destroy = library.lookupFunction<
            Void Function(Pointer<VtcSessionHandle>),
            void Function(Pointer<VtcSessionHandle>)>('vtc_session_destroy'),
        command = library.lookupFunction<
            Int32 Function(
                Pointer<VtcSessionHandle>, Int32, Uint32, Pointer<Uint8>, Int32),
            int Function(Pointer<VtcSessionHandle>, int, int, Pointer<Uint8>,
                int)>('vtc_command'),
        feedData = _feed(library, 'vtc_feed_data'),
        feedMotion = _feed(library, 'vtc_feed_motion'),
        feedMotionInfo = _feed(library, 'vtc_feed_motion_info'),
        feedPower = _feed(library, 'vtc_feed_power'),
        nextEvent = library.lookupFunction<
            Int32 Function(Pointer<VtcSessionHandle>, Pointer<VtcEvent>),
            int Function(Pointer<VtcSessionHandle>,
                Pointer<VtcEvent>)>('vtc_next_event'),
        readSamples = library.lookupFunction<
            Int32 Function(Pointer<VtcSessionHandle>, Pointer<VtcSample>, Int32),
            int Function(Pointer<VtcSessionHandle>, Pointer<VtcSample>,
                int)>('vtc_read_samples'),
        readMotion = library.lookupFunction<
            Int32 Function(
                Pointer<VtcSessionHandle>, Pointer<VtcMotionSample>, Int32),
            int Function(Pointer<VtcSessionHandle>, Pointer<VtcMotionSample>,
                int)>('vtc_read_motion'),
        contact = library.lookupFunction<
            Int32 Function(Pointer<VtcSessionHandle>, Pointer<Int32>),
            int Function(
                Pointer<VtcSessionHandle>, Pointer<Int32>)>('vtc_contact'),
        bandPower = library.lookupFunction<
            Int32 Function(Pointer<VtcSessionHandle>, Pointer<Float>),
            int Function(
                Pointer<VtcSessionHandle>, Pointer<Float>)>('vtc_band_power'),
        deviceInfo = library.lookupFunction<
            Int32 Function(Pointer<VtcSessionHandle>, Pointer<VtcDevice>),
            int Function(Pointer<VtcSessionHandle>,
                Pointer<VtcDevice>)>('vtc_device_info'),
        power = library.lookupFunction<
            Int32 Function(Pointer<VtcSessionHandle>, Pointer<VtcPowerState>),
            int Function(Pointer<VtcSessionHandle>,
                Pointer<VtcPowerState>)>('vtc_power'),
        motionAvailable = library.lookupFunction<
            Int32 Function(Pointer<VtcSessionHandle>),
            int Function(Pointer<VtcSessionHandle>)>('vtc_motion_available'),
        stats = library.lookupFunction<
            Void Function(Pointer<VtcSessionHandle>, Pointer<VtcStats>),
            void Function(
                Pointer<VtcSessionHandle>, Pointer<VtcStats>)>('vtc_get_stats');

  /// Where the library is loaded from; tests point it at a local build.
  static String? overridePath;

  static CoreLibrary? _instance;

  static CoreLibrary get instance => _instance ??= CoreLibrary._(_open());

  static DynamicLibrary _open() {
    final path = overridePath;
    if (path != null) return DynamicLibrary.open(path);
    if (Platform.isAndroid || Platform.isLinux) {
      return DynamicLibrary.open('libvitaltrack_core.so');
    }
    if (Platform.isWindows) return DynamicLibrary.open('vitaltrack_core.dll');
    if (Platform.isIOS) {
      return DynamicLibrary.open('VitalTrackCore.framework/VitalTrackCore');
    }
    throw UnsupportedError(
        'VitalTrack EEG SDK does not support ${Platform.operatingSystem}.');
  }

  static void Function(Pointer<VtcSessionHandle>, Pointer<Uint8>, int) _feed(
          DynamicLibrary library, String name) =>
      library.lookupFunction<
          Void Function(Pointer<VtcSessionHandle>, Pointer<Uint8>, Int32),
          void Function(
              Pointer<VtcSessionHandle>, Pointer<Uint8>, int)>(name);

  final int Function() version;
  final int Function(int, Pointer<Uint8>, int) uuid;
  final int Function(Pointer<Uint8>) nameMatches;
  final int Function() preferredMtu;
  final Pointer<VtcSessionHandle> Function() create;
  final void Function(Pointer<VtcSessionHandle>) destroy;
  final int Function(Pointer<VtcSessionHandle>, int, int, Pointer<Uint8>, int)
      command;
  final void Function(Pointer<VtcSessionHandle>, Pointer<Uint8>, int) feedData;
  final void Function(Pointer<VtcSessionHandle>, Pointer<Uint8>, int)
      feedMotion;
  final void Function(Pointer<VtcSessionHandle>, Pointer<Uint8>, int)
      feedMotionInfo;
  final void Function(Pointer<VtcSessionHandle>, Pointer<Uint8>, int) feedPower;
  final int Function(Pointer<VtcSessionHandle>, Pointer<VtcEvent>) nextEvent;
  final int Function(Pointer<VtcSessionHandle>, Pointer<VtcSample>, int)
      readSamples;
  final int Function(Pointer<VtcSessionHandle>, Pointer<VtcMotionSample>, int)
      readMotion;
  final int Function(Pointer<VtcSessionHandle>, Pointer<Int32>) contact;
  final int Function(Pointer<VtcSessionHandle>, Pointer<Float>) bandPower;
  final int Function(Pointer<VtcSessionHandle>, Pointer<VtcDevice>) deviceInfo;
  final int Function(Pointer<VtcSessionHandle>, Pointer<VtcPowerState>) power;
  final int Function(Pointer<VtcSessionHandle>) motionAvailable;
  final void Function(Pointer<VtcSessionHandle>, Pointer<VtcStats>) stats;
}

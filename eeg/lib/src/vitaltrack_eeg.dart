import 'dart:async';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'ble_link.dart';
import 'core_session.dart';
import 'models.dart';

/// Entry point: finds VitalTrack EEG boards and connects to them.
///
/// Use [VitalTrackEeg.instance]: the Bluetooth plugin underneath keeps one
/// scan callback and one notification callback per app, and this object owns
/// both. Notifications of other devices are handed to [onOtherDeviceValue].
class VitalTrackEeg {
  VitalTrackEeg._(this._link) {
    _link.values.listen(_route);
  }

  static VitalTrackEeg? _instance;

  static VitalTrackEeg get instance =>
      _instance ??= VitalTrackEeg._(UniversalBleLink());

  /// An instance on another link (tests, other Bluetooth stacks).
  @visibleForTesting
  factory VitalTrackEeg.withLink(BleLink link) => VitalTrackEeg._(link);

  final BleLink _link;
  final Map<String, EegConnection> _connections = <String, EegConnection>{};
  StreamSubscription<FoundDevice>? _scanSubscription;
  Timer? _scanTimer;
  StreamController<List<EegBoard>>? _scanResults;

  /// Notifications from devices that are not VitalTrack EEG connections.
  void Function(String deviceId, String characteristic, Uint8List value)?
      onOtherDeviceValue;

  /// Version of the compiled core.
  static String get coreVersion => CoreLink.version;

  /// Scans for boards for [timeout] and emits the boards found so far,
  /// strongest signal first. Bluetooth permissions must be granted first
  /// (Android 12+: BLUETOOTH_SCAN and BLUETOOTH_CONNECT).
  Stream<List<EegBoard>> scan({Duration timeout = const Duration(seconds: 10)}) {
    stopScan();
    final found = <String, EegBoard>{};
    final controller = StreamController<List<EegBoard>>();
    _scanResults = controller;
    _scanSubscription = _link.scanResults.listen((device) {
      final name = device.name;
      if (name == null || !CoreLink.nameMatches(name)) return;
      found[device.id] = EegBoard(id: device.id, name: name, rssi: device.rssi);
      final boards = found.values.toList()
        ..sort((a, b) => (b.rssi ?? -999).compareTo(a.rssi ?? -999));
      if (!controller.isClosed) controller.add(boards);
    });
    _link.startScan().catchError((Object error) {
      if (!controller.isClosed) controller.addError(error);
      stopScan();
    });
    _scanTimer = Timer(timeout, stopScan);
    return controller.stream;
  }

  Future<void> stopScan() async {
    _scanTimer?.cancel();
    _scanTimer = null;
    final subscription = _scanSubscription;
    _scanSubscription = null;
    final results = _scanResults;
    _scanResults = null;
    if (subscription == null) return;
    await subscription.cancel();
    await results?.close();
    try {
      await _link.stopScan();
    } on Object {
      // Bluetooth may have gone off; nothing left to stop.
    }
  }

  /// Connects to [board], sets up the link and checks that the board is a
  /// supported VitalTrack EEG board.
  Future<EegConnection> connect(EegBoard board,
      {Duration timeout = const Duration(seconds: 15)}) async {
    await stopScan();
    final existing = _connections[board.id];
    if (existing != null) return existing;
    final connection = EegConnection._(_link, board, () {
      _connections.remove(board.id);
    });
    _connections[board.id] = connection;
    try {
      await connection._open(timeout);
    } on Object {
      await connection._close(sendStop: false);
      rethrow;
    }
    return connection;
  }

  void _route(LinkValue value) {
    final connection = _connections[value.deviceId];
    if (connection != null) {
      connection._onValue(value);
    } else {
      onOtherDeviceValue?.call(value.deviceId, value.characteristic, value.value);
    }
  }
}

/// A connected board.
class EegConnection {
  EegConnection._(this._link, this.board, this._onClosed);

  static const Duration _responseTimeout = Duration(seconds: 2);
  static const Duration _stopTimeout = Duration(seconds: 3);
  static const int _attempts = 3;

  final BleLink _link;
  final EegBoard board;
  final void Function() _onClosed;
  final CoreSession _core = CoreSession();

  final StreamController<List<EegSample>> _eeg =
      StreamController<List<EegSample>>.broadcast();
  final StreamController<List<ContactState>> _contact =
      StreamController<List<ContactState>>.broadcast();
  final StreamController<BandPowerUpdate> _bandPower =
      StreamController<BandPowerUpdate>.broadcast();
  final StreamController<List<MotionSample>> _motion =
      StreamController<List<MotionSample>>.broadcast();
  final StreamController<BatteryState> _battery =
      StreamController<BatteryState>.broadcast();
  final StreamController<StreamNotice> _notices =
      StreamController<StreamNotice>.broadcast();
  final StreamController<EegConnectionState> _state =
      StreamController<EegConnectionState>.broadcast();

  late final String _dataService;
  late final String _dataWrite;
  late final String _dataNotify;
  late final String _auxMotion;
  late final String _auxMotionInfo;
  late final String _auxPower;
  bool _writeWithoutResponse = true;
  EegBoardInfo? _info;
  BatteryState? _lastBattery;
  StreamSubscription<bool>? _linkState;
  bool _streaming = false;
  bool _closed = false;
  final Map<int, Completer<CoreEvent>> _waiting = <int, Completer<CoreEvent>>{};

  /// What the board reported about itself.
  EegBoardInfo get info => _info!;

  /// Clean EEG, in the chunks the board sends (about 5 samples each).
  Stream<List<EegSample>> get eeg => _eeg.stream;

  /// Contact of the 8 channels (index 0 = channel 1), once a second.
  Stream<List<ContactState>> get contact => _contact.stream;

  /// Relative band power, once a second.
  Stream<BandPowerUpdate> get bandPower => _bandPower.stream;

  /// Motion-sensor samples (about 104 per second) while streaming.
  Stream<List<MotionSample>> get motion => _motion.stream;

  /// Battery state when it changes (and at least every 30 s).
  Stream<BatteryState> get battery => _battery.stream;

  /// Gaps filled in and stream restarts.
  Stream<StreamNotice> get notices => _notices.stream;

  Stream<EegConnectionState> get state => _state.stream;

  /// Last battery state, null until the board reported one.
  BatteryState? get lastBattery => _lastBattery;

  bool get isStreaming => _streaming;

  StreamStats get stats => _core.stats();

  Future<void> _open(Duration timeout) async {
    _dataService = CoreLink.uuid(CoreUuid.dataService);
    _dataWrite = CoreLink.uuid(CoreUuid.dataWrite);
    _dataNotify = CoreLink.uuid(CoreUuid.dataNotify);
    _auxMotion = CoreLink.uuid(CoreUuid.auxMotion);
    _auxMotionInfo = CoreLink.uuid(CoreUuid.auxMotionInfo);
    _auxPower = CoreLink.uuid(CoreUuid.auxPower);
    final auxService = CoreLink.uuid(CoreUuid.auxService);

    await _link.connect(board.id, timeout);
    _linkState = _link.connection(board.id).listen((connected) {
      if (!connected) _handleLinkLost();
    });

    final services = await _link.services(board.id);
    LinkService? data;
    LinkService? aux;
    for (final service in services) {
      if (service.uuid == _dataService) data = service;
      if (service.uuid == auxService) aux = service;
    }
    if (data == null ||
        !data.characteristics.containsKey(_dataWrite) ||
        !data.characteristics.containsKey(_dataNotify)) {
      throw const VitalTrackException('Not a VitalTrack EEG board.');
    }
    _writeWithoutResponse = data.characteristics[_dataWrite] ?? true;

    try {
      await _link.requestMtu(board.id, CoreLink.preferredMtu);
    } on Object {
      // Not supported everywhere (Linux, iOS negotiate on their own).
    }
    await _link.notify(board.id, _dataService, _dataNotify);

    if (aux != null) {
      if (aux.characteristics.containsKey(_auxMotionInfo)) {
        _core.feedMotionInfo(
            await _link.read(board.id, auxService, _auxMotionInfo));
      }
      if (aux.characteristics.containsKey(_auxMotion)) {
        await _link.notify(board.id, auxService, _auxMotion);
      }
      if (aux.characteristics.containsKey(_auxPower)) {
        _core.feedPower(await _link.read(board.id, auxService, _auxPower));
        await _link.notify(board.id, auxService, _auxPower);
      }
      _drain();
    }

    final identified = await _request(
        CoreEventType.identified, () => _core.command(CoreCommand.identify));
    if (identified.code != 0) {
      throw VitalTrackException(identified.code == 1
          ? 'This board firmware is not supported by this SDK version.'
          : 'The board did not identify itself.');
    }
    _info = _core.boardInfo();
    _state.add(EegConnectionState.connected);
  }

  /// Starts streaming the given channels (numbers 1 to 8). Contact, band
  /// power and motion start with it.
  Future<void> start({required Set<int> channels}) async {
    _checkOpen();
    if (_streaming) throw const VitalTrackException('Already streaming.');
    if (channels.isEmpty || channels.any((c) => c < 1 || c > 8)) {
      throw ArgumentError.value(channels, 'channels', 'must be 1 to 8');
    }
    final mask = channels.fold<int>(0, (m, c) => m | (1 << (c - 1)));
    final applied =
        await _request(CoreEventType.channels, () => _core.command(CoreCommand.setChannels, mask));
    if (applied.code != 0 || applied.value1 != mask) {
      throw const VitalTrackException('The board did not accept the channels.');
    }
    await _send(_core.command(CoreCommand.start));
    _streaming = true;
  }

  /// Stops streaming. Waits until the board has sent everything it measured.
  Future<StopResult> stop() async {
    _checkOpen();
    if (!_streaming) {
      return StopResult(sampleCount: _core.stats().samples, confirmed: true);
    }
    final waiting = _waitFor(CoreEventType.stopped);
    await _send(_core.command(CoreCommand.stop));
    var confirmed = true;
    try {
      await waiting.future.timeout(_stopTimeout);
    } on TimeoutException {
      confirmed = false;
    } finally {
      _waiting.remove(CoreEventType.stopped);
    }
    _streaming = false;
    return StopResult(sampleCount: _core.stats().samples, confirmed: confirmed);
  }

  /// Stops streaming if needed and disconnects.
  Future<void> disconnect() => _close(sendStop: true);

  Future<void> _close({required bool sendStop}) async {
    if (_closed) return;
    if (sendStop && _streaming) {
      try {
        await stop();
      } on Object {
        // Disconnecting anyway.
      }
    }
    _closed = true;
    _onClosed();
    await _linkState?.cancel();
    try {
      await _link.disconnect(board.id);
    } on Object {
      // Already gone.
    }
    _streaming = false;
    _state.add(EegConnectionState.disconnected);
    _core.dispose();
    for (final controller in <StreamController<Object?>>[
      _eeg, _contact, _bandPower, _motion, _battery, _notices, _state
    ]) {
      await controller.close();
    }
  }

  void _handleLinkLost() {
    if (_closed) return;
    _streaming = false;
    for (final waiting in _waiting.values) {
      if (!waiting.isCompleted) {
        waiting.completeError(const VitalTrackException('Connection lost.'));
      }
    }
    _close(sendStop: false);
  }

  void _checkOpen() {
    if (_closed) throw const VitalTrackException('The connection is closed.');
  }

  Completer<CoreEvent> _waitFor(int type) {
    final completer = Completer<CoreEvent>();
    _waiting[type] = completer;
    return completer;
  }

  /// Sends a command and waits for the event that answers it, retrying a
  /// command the board ignored (it does while finishing a stop).
  Future<CoreEvent> _request(int type, Uint8List Function() command) async {
    for (var attempt = 1;; attempt++) {
      final waiting = _waitFor(type);
      await _send(command());
      try {
        return await waiting.future.timeout(_responseTimeout);
      } on TimeoutException {
        if (attempt >= _attempts) {
          throw const VitalTrackException('The board did not answer.');
        }
      } finally {
        _waiting.remove(type);
      }
    }
  }

  Future<void> _send(Uint8List bytes) =>
      _link.write(board.id, _dataService, _dataWrite, bytes, _writeWithoutResponse);

  void _onValue(LinkValue value) {
    if (_closed) return;
    final characteristic = value.characteristic;
    if (characteristic == _dataNotify) {
      _core.feedData(value.value);
    } else if (characteristic == _auxMotion) {
      _core.feedMotion(value.value);
    } else if (characteristic == _auxPower) {
      _core.feedPower(value.value);
    } else if (characteristic == _auxMotionInfo) {
      _core.feedMotionInfo(value.value);
    } else {
      return;
    }
    _drain();
  }

  void _drain() {
    final samples = _core.takeSamples();
    if (samples.isNotEmpty) _eeg.add(samples);
    final motion = _core.takeMotion();
    if (motion.isNotEmpty) _motion.add(motion);
    for (final event in _core.takeEvents()) {
      final waiting = _waiting[event.type];
      if (waiting != null && !waiting.isCompleted) waiting.complete(event);
      switch (event.type) {
        case CoreEventType.contact:
          _contact.add(_core.contact());
        case CoreEventType.bandPower:
          _bandPower.add(_core.bandPower());
        case CoreEventType.power:
          final battery = _core.battery();
          _lastBattery = battery;
          _battery.add(battery);
        case CoreEventType.gap:
          _notices.add(StreamNotice(StreamNoticeKind.gapFilled, event.value1));
        case CoreEventType.discontinuity:
          _notices.add(StreamNotice(StreamNoticeKind.restarted, event.value1));
        case CoreEventType.stopped:
          _streaming = false;
      }
    }
  }
}

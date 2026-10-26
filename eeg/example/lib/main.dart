// VitalTrack EEG SDK example: scan, connect, choose channels, stream clean
// EEG with contact and band power, and save it to a CSV file yourself.
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vitaltrack_eeg/vitaltrack_eeg.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VitalTrack SDK 예제',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF24306B)),
      home: const ExampleHome(),
    );
  }
}

class ExampleHome extends StatefulWidget {
  const ExampleHome({super.key});

  @override
  State<ExampleHome> createState() => _ExampleHomeState();
}

class _ExampleHomeState extends State<ExampleHome> {
  static const int _plotSamples = 250 * 5;
  static const int _motionSamples = 104 * 5;
  static const List<Color> _axisColors = <Color>[
    Color(0xFFC2414D),
    Color(0xFF0F9D8A),
    Color(0xFF24306B),
  ];

  final VitalTrackEeg _sdk = VitalTrackEeg.instance;
  final Set<int> _channels = <int>{1, 2, 3, 4, 5, 6, 7, 8};
  final List<List<double>> _plot = List<List<double>>.generate(
    8,
    (_) => <double>[],
  );
  final List<EegSample> _recorded = <EegSample>[];
  // x, y, z of the last 5 s of motion.
  final List<List<double>> _acceleration = List<List<double>>.generate(
    3,
    (_) => <double>[],
  );
  final List<List<double>> _rotation = List<List<double>>.generate(
    3,
    (_) => <double>[],
  );

  List<EegBoard> _boards = const <EegBoard>[];
  StreamSubscription<List<EegBoard>>? _scan;
  EegConnection? _connection;
  final List<StreamSubscription<Object?>> _subscriptions =
      <StreamSubscription<Object?>>[];
  List<ContactState> _contact = List<ContactState>.filled(
    8,
    ContactState.unused,
  );
  BandPowerUpdate? _bands;
  BatteryState? _battery;
  int _samples = 0;
  int _filled = 0;
  bool _recording = false;
  String _status = '장비를 검색하세요.';

  Future<void> _startScan() async {
    try {
      await _requestPermissions();
    } on Object catch (error) {
      setState(() => _status = '권한이 필요합니다: $error');
      return;
    }
    setState(() {
      _boards = const <EegBoard>[];
      _status = '검색 중…';
    });
    await _scan?.cancel();
    _scan = _sdk
        .scan(timeout: const Duration(seconds: 8))
        .listen(
          (boards) => setState(() => _boards = boards),
          onError: (Object error) => setState(() => _status = '검색 실패: $error'),
          onDone: () => setState(() => _status = '검색 끝 (${_boards.length}대)'),
        );
  }

  /// Android 12+: scan and connect; older Android: location. Other
  /// platforms ask on first use.
  Future<void> _requestPermissions() async {
    if (kIsWeb || !Platform.isAndroid) return;
    final statuses = await <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    final scanOk = statuses[Permission.bluetoothScan]?.isGranted ?? false;
    final connectOk = statuses[Permission.bluetoothConnect]?.isGranted ?? false;
    final locationOk =
        statuses[Permission.locationWhenInUse]?.isGranted ?? false;
    if (!(scanOk && connectOk) && !locationOk) {
      throw const VitalTrackException('Bluetooth');
    }
  }

  Future<void> _connect(EegBoard board) async {
    setState(() => _status = '${board.name} 연결 중…');
    try {
      final connection = await _sdk.connect(board);
      _subscriptions
        ..add(connection.eeg.listen(_onSamples))
        ..add(connection.motion.listen(_onMotion))
        ..add(connection.contact.listen((c) => setState(() => _contact = c)))
        ..add(connection.bandPower.listen((b) => setState(() => _bands = b)))
        ..add(connection.battery.listen((b) => setState(() => _battery = b)))
        ..add(
          connection.notices.listen((n) {
            if (n.kind == StreamNoticeKind.restarted) {
              setState(() => _status = '연결이 잠시 끊겨 처리를 다시 시작했습니다.');
            }
          }),
        )
        ..add(
          connection.state.listen((state) {
            if (state == EegConnectionState.disconnected) _onDisconnected();
          }),
        );
      setState(() {
        _connection = connection;
        _battery = connection.lastBattery;
        _status = '연결됨 · 펌웨어 ${connection.info.firmwareVersion}';
      });
    } on Object catch (error) {
      setState(() => _status = '연결 실패: $error');
    }
  }

  void _onSamples(List<EegSample> samples) {
    for (final sample in samples) {
      for (var c = 0; c < 8; c++) {
        final lane = _plot[c];
        lane.add(sample.microvolts[c]);
        if (lane.length > _plotSamples) lane.removeAt(0);
      }
      if (sample.filled) _filled++;
    }
    if (_recording) _recorded.addAll(samples);
    _samples += samples.length;
    setState(() {});
  }

  void _onMotion(List<MotionSample> samples) {
    for (final sample in samples) {
      for (var axis = 0; axis < 3; axis++) {
        _acceleration[axis].add(sample.accelerationG[axis]);
        _rotation[axis].add(sample.rotationDps[axis]);
        if (_acceleration[axis].length > _motionSamples) {
          _acceleration[axis].removeAt(0);
          _rotation[axis].removeAt(0);
        }
      }
    }
    setState(() {});
  }

  Future<void> _start() async {
    final connection = _connection;
    if (connection == null) return;
    try {
      for (final lane in [..._plot, ..._acceleration, ..._rotation]) {
        lane.clear();
      }
      _recorded.clear();
      _samples = 0;
      _filled = 0;
      await connection.start(channels: _channels);
      setState(() {
        _recording = true;
        _status = '측정 중';
      });
    } on Object catch (error) {
      setState(() => _status = '시작 실패: $error');
    }
  }

  Future<void> _stop() async {
    final connection = _connection;
    if (connection == null) return;
    final result = await connection.stop();
    setState(() {
      _recording = false;
      _status =
          '정지 · 샘플 ${result.sampleCount}개'
          '${result.confirmed ? '' : ' (장비 확인 없음)'}';
    });
  }

  /// Saving is the app's job: here, the clean samples as CSV.
  Future<void> _save() async {
    if (_recorded.isEmpty) return;
    // Android: the app's folder under Android/data, which a PC can read over
    // USB (adb pull). Elsewhere: the documents folder.
    final directory =
        (!kIsWeb && Platform.isAndroid
            ? await getExternalStorageDirectory()
            : null) ??
        await getApplicationDocumentsDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}'
      'vitaltrack_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
    final buffer = StringBuffer(
      'index,time_s,filled,'
      '${List<String>.generate(8, (c) => 'ch${c + 1}_uv').join(',')}\n',
    );
    for (final s in _recorded) {
      buffer
        ..write(s.index)
        ..write(',')
        ..write((s.index / 250).toStringAsFixed(3))
        ..write(',')
        ..write(s.filled ? 1 : 0);
      for (final v in s.microvolts) {
        buffer
          ..write(',')
          ..write(v.toStringAsFixed(3));
      }
      buffer.write('\n');
    }
    await file.writeAsString(buffer.toString());
    setState(() => _status = '저장: ${file.path}');
  }

  Future<void> _disconnect() async {
    await _connection?.disconnect();
  }

  void _onDisconnected() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _subscriptions.clear();
    setState(() {
      _connection = null;
      _recording = false;
      _contact = List<ContactState>.filled(8, ContactState.unused);
      _status = '연결 끊김';
    });
  }

  @override
  void dispose() {
    _scan?.cancel();
    _connection?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connection = _connection;
    return Scaffold(
      appBar: AppBar(
        title: Text('VitalTrack SDK ${VitalTrackEeg.coreVersion}'),
        actions: [
          if (_battery?.percent != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(child: Text('배터리 ${_battery!.percent}%')),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_status),
            const SizedBox(height: 8),
            if (connection == null) ...[
              FilledButton(onPressed: _startScan, child: const Text('검색')),
              for (final board in _boards)
                ListTile(
                  title: Text(board.name),
                  subtitle: Text('${board.id} · ${board.rssi ?? '-'} dBm'),
                  onTap: () => _connect(board),
                ),
            ] else ...[
              Wrap(
                spacing: 6,
                children: [
                  for (var c = 1; c <= 8; c++)
                    FilterChip(
                      label: Text('CH$c'),
                      selected: _channels.contains(c),
                      onSelected: _recording
                          ? null
                          : (on) => setState(
                              () => on ? _channels.add(c) : _channels.remove(c),
                            ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  FilledButton(
                    onPressed: _recording || _channels.isEmpty ? null : _start,
                    child: const Text('시작'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _recording ? _stop : null,
                    child: const Text('정지'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: !_recording && _recorded.isNotEmpty
                        ? _save
                        : null,
                    child: const Text('CSV 저장'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _disconnect,
                    child: const Text('연결 해제'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('샘플 $_samples · 채운 샘플 $_filled'),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: [
                    if (connection.info.motionAvailable) ...[
                      _motionLane('가속도', 'g', _acceleration, 0.02),
                      _motionLane('각속도', '°/s', _rotation, 5),
                    ] else
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('움직임 센서 없음'),
                      ),
                    for (var c = 1; c <= 8; c++)
                      if (_channels.contains(c)) _lane(c),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _lane(int channel) {
    final contact = _contact[channel - 1];
    final alpha = _bands?.percent(channel, EegBand.alpha);
    final values = _plot[channel - 1];
    final (centers, halfRange) = _laneScale(<List<double>>[values], 20);
    return SizedBox(
      height: 64,
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CH$channel',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  _contactLabel(contact),
                  style: TextStyle(color: _contactColor(contact), fontSize: 12),
                ),
                Text(
                  '${alpha == null ? 'α -' : 'α ${alpha.round()}%'}'
                  ' · ±${_formatRange(halfRange)} µV',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(
            child: CustomPaint(
              painter: _LanePainter(
                <List<double>>[values],
                const <Color>[Color(0xFF24306B)],
                capacity: _plotSamples,
                centers: centers,
                halfRange: halfRange,
              ),
              // Without a child the painter got no height and every
              // sample landed on one line.
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }

  /// x, y, z of acceleration or rotation in one lane.
  Widget _motionLane(
    String title,
    String unit,
    List<List<double>> axes,
    double minimumRange,
  ) {
    final (centers, halfRange) = _laneScale(axes, minimumRange);
    String latest(int axis) =>
        axes[axis].isEmpty ? '-' : axes[axis].last.toStringAsFixed(2);
    return SizedBox(
      height: 64,
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$title ($unit)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      for (var axis = 0; axis < 3; axis++)
                        TextSpan(
                          text:
                              '${const ['x', 'y', 'z'][axis]} ${latest(axis)} ',
                          style: TextStyle(color: _axisColors[axis]),
                        ),
                    ],
                  ),
                  style: const TextStyle(fontSize: 11),
                ),
                Text(
                  '±${_formatRange(halfRange)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(
            child: CustomPaint(
              painter: _LanePainter(
                axes,
                _axisColors,
                capacity: _motionSamples,
                centers: centers,
                halfRange: halfRange,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }

  /// Each lane scales itself to what it shows: every series centred on its
  /// own mean (so gravity on one axis does not squash the others) and the
  /// largest swing rounded up to 1, 2 or 5 x 10^n (at least [minimumRange]).
  /// An electrode off the skin swings by tens of thousands of uV; a fixed
  /// +-100 uV lane would clip it.
  static (List<double>, double) _laneScale(
    List<List<double>> series,
    double minimumRange,
  ) {
    final centers = <double>[
      for (final s in series)
        s.isEmpty ? 0 : s.reduce((a, b) => a + b) / s.length,
    ];
    var swing = 0.0;
    for (var k = 0; k < series.length; k++) {
      for (final v in series[k]) {
        swing = math.max(swing, (v - centers[k]).abs());
      }
    }
    var range = minimumRange;
    if (range < swing) {
      final decade = math.pow(10, (math.log(swing) / math.ln10).floor());
      for (final step in const <double>[1, 2, 5, 10]) {
        range = step * decade;
        if (range >= swing) break;
      }
    }
    return (centers, range);
  }

  static String _formatRange(double range) => range >= 1000
      ? '${(range / 1000).toStringAsFixed(0)}k'
      : range >= 1
      ? range.toStringAsFixed(0)
      : range.toStringAsFixed(2);

  static String _contactLabel(ContactState state) => switch (state) {
    ContactState.good => '정상',
    ContactState.weak => '약함',
    ContactState.detached => '부착 안됨',
    ContactState.waiting => '대기',
    ContactState.unused => '사용 안 함',
  };

  static Color _contactColor(ContactState state) => switch (state) {
    ContactState.good => const Color(0xFF0F9D8A),
    ContactState.weak => const Color(0xFFD97706),
    ContactState.detached => const Color(0xFFC2414D),
    _ => const Color(0xFF8B95A7),
  };
}

/// The last few seconds of one or more series, each [centers] +- [halfRange].
class _LanePainter extends CustomPainter {
  _LanePainter(
    this.series,
    this.colors, {
    required this.capacity,
    required this.centers,
    required this.halfRange,
  });

  /// Grow in place as samples arrive, so every frame repaints.
  final List<List<double>> series;
  final List<Color> colors;

  /// Points across the full width.
  final int capacity;
  final List<double> centers;
  final double halfRange;

  @override
  void paint(Canvas canvas, Size size) {
    final step = size.width / capacity;
    for (var k = 0; k < series.length; k++) {
      final values = series[k];
      if (values.length < 2) continue;
      final paint = Paint()
        ..color = colors[k % colors.length]
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      final path = Path();
      for (var i = 0; i < values.length; i++) {
        final scaled = ((values[i] - centers[k]) / halfRange).clamp(-1.0, 1.0);
        final y = size.height / 2 - scaled * size.height / 2;
        if (i == 0) {
          path.moveTo(i * step, y);
        } else {
          path.lineTo(i * step, y);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_LanePainter old) => true;
}

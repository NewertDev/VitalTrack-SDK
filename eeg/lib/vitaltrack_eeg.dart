/// VitalTrack EEG SDK: connect to a VitalTrack EEG board and receive clean
/// EEG, electrode contact, band power, motion and battery state.
///
/// ```dart
/// final sdk = VitalTrackEeg.instance;
/// final boards = await sdk.scan().first;
/// final board = await sdk.connect(boards.first);
/// board.eeg.listen((samples) { /* save or show */ });
/// await board.start(channels: {1, 2, 3, 4});
/// ...
/// await board.stop();
/// await board.disconnect();
/// ```
library;

export 'src/models.dart';
export 'src/vitaltrack_eeg.dart' show VitalTrackEeg, EegConnection;

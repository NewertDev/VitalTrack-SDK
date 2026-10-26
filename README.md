# Newert VitalTrack SDK

Newert VitalTrack 장비에서 데이터를 받는 Flutter SDK 모음입니다. 장비마다 폴더가 하나씩 있습니다.

| SDK | 폴더 | 패키지 | 최신 버전 | 플랫폼 |
|---|---|---|---|---|
| **VitalTrack EEG** — 정제된 EEG(최대 8채널, 250 Hz), 전극 접촉, 밴드파워, 움직임, 배터리 | [`eeg/`](eeg/README.md) | `vitaltrack_eeg` | [`eeg-v0.1.0`](../../tree/eeg-v0.1.0/eeg) | Android, Windows, Linux (iOS 준비 중) |
| **VitalTrack & EmoConnect** — PPG, IMU | [`ppg/`](ppg/README.md) | — | `ppg-legacy` | Android, iOS |

## 설치 (EEG)

`pubspec.yaml`에 추가하고 `flutter pub get`을 실행합니다.

```yaml
dependencies:
  vitaltrack_eeg:
    git:
      url: https://github.com/NewertDev/VitalTrack-SDK.git
      path: eeg
      ref: eeg-v0.1.0
```

```dart
import 'package:vitaltrack_eeg/vitaltrack_eeg.dart';

final boards = await VitalTrackEeg.instance.scan().firstWhere((l) => l.isNotEmpty);
final board = await VitalTrackEeg.instance.connect(boards.first);
board.eeg.listen((samples) { /* 정제된 EEG (µV) */ });
await board.start(channels: {1, 2, 3, 4});
```

사용법, 제공 데이터, 플랫폼별 권한 설정은 [`eeg/README.md`](eeg/README.md), 실행해 볼 수 있는 앱은
[`eeg/example/`](eeg/example)에 있습니다.

## 버전

- SDK마다 따로 태그를 붙입니다: `eeg-v<버전>`, `ppg-v<버전>`. 목록은 [Tags](../../tags)에서 볼 수 있습니다.
- `ref`에 태그를 적어 버전을 고정하세요. 변경 내용은 각 폴더의 `CHANGELOG.md`에 있습니다.
- 이 저장소의 루트에 PPG 코드가 있던 예전 구조는 `ppg-legacy` 태그로 남아 있습니다.

## 라이선스

Newert의 독점 소프트웨어입니다. 각 폴더의 `LICENSE`를 확인하세요.

---

# Newert VitalTrack SDK (English)

Flutter SDKs for Newert VitalTrack devices, one folder per device.

| SDK | Folder | Package | Latest | Platforms |
|---|---|---|---|---|
| **VitalTrack EEG** — clean EEG (up to 8 channels, 250 Hz), electrode contact, band power, motion, battery | [`eeg/`](eeg/README.md) | `vitaltrack_eeg` | [`eeg-v0.1.0`](../../tree/eeg-v0.1.0/eeg) | Android, Windows, Linux (iOS coming) |
| **VitalTrack & EmoConnect** — PPG, IMU | [`ppg/`](ppg/README.md) | — | `ppg-legacy` | Android, iOS |

Install the EEG SDK by adding it to `pubspec.yaml` as a git dependency (`path: eeg`, `ref: eeg-v0.1.0`,
see above). Each SDK is tagged separately (`eeg-v*`, `ppg-v*`); pin a tag with `ref`. The old layout,
with the PPG code at the repository root, is kept under the `ppg-legacy` tag.

Proprietary software of Newert. See `LICENSE` in each folder.

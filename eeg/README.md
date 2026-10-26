# VitalTrack EEG SDK (Flutter) 0.1.0

VitalTrack EEG 보드에 연결해 **정제된 EEG**, 전극 접촉 상태, 밴드파워,
움직임(가속도·자이로), 배터리 상태를 받는 Flutter 패키지입니다.

- 보드 연결, 통신, 신호 처리는 SDK가 합니다. 앱은 함수를 호출하고 데이터를 받기만 하면 됩니다.
- 데이터 **저장은 앱이 합니다.** SDK는 스트림만 제공합니다.
- 제공되는 EEG는 정제된 신호입니다(대역 필터, 전원 잡음 제거, 공통 기준 적용).

| 플랫폼 | 지원 |
|---|---|
| Android | 7.0 (API 24) 이상, arm64-v8a / armeabi-v7a / x86_64 |
| iOS | 준비 중 (다음 버전, 13.0 이상) |
| Windows | 10 이상, x64 |
| Linux | x64, glibc 2.34 이상 (Ubuntu 22.04 이상), BlueZ |

## 설치

`pubspec.yaml`에 추가하고 `flutter pub get`을 실행합니다. `ref`로 버전을 고정합니다
(버전 목록: 저장소의 Tags, 변경 내용: `CHANGELOG.md`).

```yaml
dependencies:
  vitaltrack_eeg:
    git:
      url: https://github.com/NewertDev/VitalTrack-SDK.git
      path: eeg
      ref: eeg-v0.1.0
```

zip으로 받았다면 `vitaltrack_eeg` 폴더를 프로젝트 옆에 두고 경로로 추가합니다.

```yaml
dependencies:
  vitaltrack_eeg:
    path: ../vitaltrack_eeg
```

## 빠른 시작

```dart
import 'package:vitaltrack_eeg/vitaltrack_eeg.dart';

final sdk = VitalTrackEeg.instance;

// 1. 검색: 찾은 보드 목록이 갱신될 때마다 들어옵니다 (기본 10초).
final boards = await sdk.scan(timeout: const Duration(seconds: 5))
    .firstWhere((list) => list.isNotEmpty);

// 2. 연결
final board = await sdk.connect(boards.first);
print(board.info.firmwareVersion);

// 3. 데이터 받기 (저장은 앱에서)
board.eeg.listen((samples) {
  for (final s in samples) {
    // s.index: 0부터 1초에 250씩. 시간(초) = s.index / 250
    // s.microvolts[0..7]: 채널 1~8의 정제 EEG (µV). 쓰지 않는 채널은 0
    // s.filled: 무선 구간에서 빠져 앞뒤 값으로 채운 샘플
  }
});
board.contact.listen((states) { /* 1초마다, 채널별 ContactState */ });
board.bandPower.listen((bands) {
  final alpha = bands.percent(1, EegBand.alpha); // 채널 1 알파 비율(%)
});

// 4. 측정 시작 (사용할 채널 번호 1~8)
await board.start(channels: {1, 2, 3, 4});

// 5. 정지와 연결 해제
final result = await board.stop();
await board.disconnect();
```

전체 예제는 `example/`에 있습니다(검색, 연결, 채널 선택, 파형, CSV 저장).

## 제공 데이터

| 스트림 | 내용 | 주기 |
|---|---|---|
| `eeg` | `List<EegSample>`: 정제 EEG 8채널 (µV) | 보드가 보내는 묶음 단위 (약 5샘플, 1초 250샘플) |
| `contact` | `List<ContactState>` 8개: `good`(정상), `weak`(약함), `detached`(부착 안됨), `waiting`(판정 전), `unused`(사용 안 함) | 1초 |
| `bandPower` | `BandPowerUpdate`: 채널별 δ θ α β γ 상대 비율 (%), 최근 8초 | 1초 |
| `motion` | `List<MotionSample>`: 가속도(g)·회전(°/s), EEG 시간축 위치 포함 | 약 104 Hz |
| `battery` | `BatteryState`: 잔량(%), 전압(mV), 전원(배터리/USB 충전 중/USB 충전 완료) | 변할 때, 최소 30초마다 |
| `notices` | 채운 구간(`gapFilled`), 처리 재시작(`restarted`) | 발생할 때 |
| `state` | `connected` / `disconnected` | 변할 때 |

- **접촉 상태**는 신호를 보고 판정한 추정값이며 임피던스 측정이 아닙니다.
- **처리 재시작(`restarted`)**: 연결이 10초 넘게 끊겼다 이어지면 필터를 처음부터 다시 시작합니다. 그다음 몇 초는 신호가 안정되는 구간입니다.
- **연결 끊김**: `state`에 `disconnected`가 오면 연결 객체는 닫힙니다. 다시 `connect()`로 연결하세요.

## 플랫폼별 준비

### Android

`android/app/src/main/AndroidManifest.xml`에 권한을 넣고, 검색 전에 실행 중 권한을 요청하세요
(예: `permission_handler` 패키지, 예제 앱 참고).

```xml
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
```

### iOS

`ios/Runner/Info.plist`에 블루투스 사용 문구를 넣습니다.

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>EEG 장비와 연결하는 데 블루투스를 사용합니다.</string>
```

### Linux

BlueZ가 실행 중이어야 합니다(`systemctl status bluetooth`). 사용자 계정이 블루투스를
쓸 수 있어야 합니다(배포판에 따라 `bluetooth` 그룹).

### Windows

추가 설정이 없습니다. 블루투스 LE를 지원하는 어댑터가 필요합니다.

## 알아 둘 점

- SDK는 Bluetooth 플러그인 `universal_ble`을 사용하며, 이 플러그인의 검색·알림 콜백을
  SDK가 차지합니다. 앱에서 다른 BLE 장비도 다룬다면 그 장비의 알림은
  `VitalTrackEeg.instance.onOtherDeviceValue`로 받으세요.
- 보드 한 대에 연결 하나입니다. 여러 대는 보드마다 `connect()`를 호출합니다.
- 정제 신호는 실시간(인과) 필터를 거치므로 주파수에 따라 지연이 있습니다:
  5–40 Hz는 약 10–18 ms, 2 Hz는 약 60 ms, 1 Hz는 약 250 ms. 자극 시점에 맞춘
  분석(ERP 등)에서는 이 지연을 감안하세요.

## 라이선스

Newert의 독점 소프트웨어입니다. `LICENSE`를 확인하세요.

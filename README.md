# VitalTrack SDK

## Features
소개
VitalTrack SDK는 BLE 장치를 활용하여 PPG 및 IMU 데이터를 수집하고 처리할 수 있는 Flutter 기반 라이브러리입니다. 이 SDK를 통해 실시간으로 생체신호를 기록하고, 장치 간 BLE 통신을 간편하게 구현할 수 있습니다.

### 1. 사용법
VitalTrack SDK는 BLE 장치와 연결, 데이터 수집, 명령 전송 기능을 포함합니다. 아래에 주요 기능 사용 예시를 제공합니다.

### 2.1 BLE 장치 스캔 및 연결
BLE 장치 스캔을 시작하고 원하는 장치에 연결할 수 있습니다.
``` 
final bleController = BleController();  // 컨트롤러 인스턴스 생성

void startScanAndConnect() async {
  bleController.startScan();  // 스캔 시작

  // 스캔된 장치 중 첫 번째 장치와 연결
  if (bleController.devices.isNotEmpty) {
    DiscoveredDevice selectedDevice = bleController.devices.first;
    await bleController.connectToDevice(selectedDevice);
  }
}
```

### 1.2 데이터 수집 및 실시간 처리
PPG 및 IMU 데이터를 수집하고 처리하는 타이머를 설정합니다

```
void startDataCollection() {
  bleController.writeCMDToDevice(CMD.START_PPG);  // 데이터 수집 시작
  _startGetDataTimer();  // 1초 간격으로 데이터 수집
}

void _startGetDataTimer() {
  Timer.periodic(const Duration(seconds: 1), (timer) {
    List<double> ppgData = bleController.receivedPPGDataQueue.toList();
    bleController.receivedPPGDataQueue.clear();

    print("1초 간격의 PPG 데이터: $ppgData");
  });
}
```

### 1.3 BLE 장치에 명령어 전송
BLE 장치에 명령어를 전송할 수 있습니다.
```
void setTimeToDevice() {
  String time = DateTime.now().toString();
  bleController.writeDataToDevice("SET TIME $time");
}

void sendHeartRateToDevice(double hr) {
  bleController.writeDataToDevice("SET BPM ${hr.toStringAsFixed(0)}");
}
```


### 1.4 데이터 중지 및 장치 재부팅
장치에서 데이터를 중지하고 필요 시 재부팅합니다.
```
void stopAndRebootDevice() {
  bleController.writeCMDToDevice(CMD.STOP_PPG);
  bleController.writeCMDToDevice(CMD.REBOOT_PPG);
}
```

## Permissions
Ensure to request the necessary permissions for Bluetooth and location services. The BleScreen and MeasureScreen widgets include methods to request these permissions using the permission_handler package.
BLE 통신과 데이터 저장을 위해 앱에서 저장소 접근 권한을 요청합니다.
```
Future<void> requestPermissions() async {
  var status = await Permission.storage.status;
  if (!status.isGranted) {
    await Permission.storage.request();
  }
}
```


## Contributing
Contributions are welcome! Please submit pull requests or open issues for any bugs or feature requests.

## Requirements
Dart SDK >=2.12.0 <3.0.0
Flutter SDK >=2.0.0
Android API Level 23+

# VitalTrack SDK

## 소개
**VitalTrack SDK**는 BLE 장치를 활용하여 **PPG 및 IMU 데이터를 수집하고 처리**할 수 있는 Flutter 기반 라이브러리입니다. 
이 SDK를 통해 실시간으로 **생체신호를 기록**하고, 장치 간 BLE 통신을 간편하게 구현할 수 있습니다.

### 1. 사용법
VitalTrack SDK는 **BLE 장치와 연결, 데이터 수집, 명령 전송 기능**을 포함합니다. 아래에 주요 기능 사용 예시를 제공합니다.

### 1.1 BLE 장치 스캔 및 연결
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

## 권한
BLE 통신과 데이터 저장을 위해 앱에서 저장소 접근 권한을 요청합니다.
```
Future<void> requestPermissions() async {
  var status = await Permission.storage.status;
  if (!status.isGranted) {
    await Permission.storage.request();
  }
}
```
</br>

## SDK가 제공하는 결과 데이터
장비에서 측정한 결과 데이터를 SDK에서 확인할 수 있습니다.</br>
다음과 같은 결과 데이터 항목들이 제공됩니다.
<ol>
<li>PPG: PPG(Photoplethysmography)의 raw data, 초당 50개(50Hz)</li> 
<li>9 Axis IMU data</li>   
 <ul>
   <li>
     ACC: 가속도(Acceleration) 데이터, 초당 50개(50Hz)
   </li>
   <li>
     GYRO: 자이로스코프(Gyroscope) 데이터, 초당 50개(50Hz)
   </li>
   <li>
     MAG: 지자기(Magnetometer) 데이터, 초당 50개(50Hz)
   </li>   
 </ul>
</ol>

</br>
</br>



## 요구사항
아래는 SDK의 실행을 위한 환경 요구사항입니다.

### 시스템 요구사항:
Flutter SDK: >=3.0.0
Dart SDK: >=2.18.0
Android API: 23 이상
Windows OS: 10 이상

## 개발 환경
- Flutter 버전: 3.22.2 (채널 stable)
- Android SDK 버전: 34.0.0
- Visual Studio Community 2022: 17.3.6
- Android Studio: 2022.3 (최신 버전 권장)

## 주의사항
- Android Studio 설치 시, Java 버전을 올바르게 설정해야 합니다.
- BLE 권한이 필요한 플랫폼에서는 권한 요청을 반드시 수행하세요.
- BLE 장치와의 연결 시 네트워크 상태 및 거리도 확인해 주세요.


문의 및 지원: 자세한 내용은 공식 웹사이트(www.newert.co.kr) 에서 확인할 수 있습니다.

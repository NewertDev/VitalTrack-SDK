# VitalTrack SDK
VitalTrack SDK is a comprehensive solution designed to facilitate the integration and management of Bluetooth Low Energy (BLE) devices within Flutter applications. The SDK provides a robust set of tools for scanning, connecting, and interacting with BLE devices, making it an ideal choice for developers working on health tracking, fitness, or any IoT projects requiring BLE communication.

![VitalTrack image](https://github.com/NewertDev/VitalTrack-SDK/assets/142801626/7a68b848-65ed-4ebf-b132-a7a5a03e1ec0)


## Features
1. Bluetooth Device Scanning: Discover nearby BLE devices and list them for user selection.
2. Device Connection: Seamlessly connect to BLE devices and manage connection states.
3. Service and Characteristic Discovery: Automatically discover and interact with device services and characteristics.
4. Data Subscription: Subscribe to data streams from connected devices, including PPG, ACC, Gyro, and Mag data.
5. Command Writing: Send commands to connected devices to control their operations.
6. Error Handling and Reconnection: Robust handling of connection errors with automatic reconnection attempts.

## Usage
Import the necessary packages and initialize the BleController in your main widget:
### Initialization
```   
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'controller/bleController.dart';
import 'view/bleScreen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      home: BleScreen(),
    );
  }
}

```   

### BLE Controller
The BleController handles all BLE operations. It scans for devices, connects to them, discovers services and characteristics, and subscribes to data streams.
```   
import 'package:newert_vitaltrack/src/processing.dart';
import 'package:newert_vitaltrack/src/bleStatus.dart';

import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:get/get.dart';

class BleController extends GetxController {
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  var isScanning = false.obs;
  var devices = <DiscoveredDevice>[].obs;
  var connectedDevices = <DiscoveredDevice>[].obs;
  DiscoveredDevice? currentDevice;

  StreamSubscription<ConnectionStateUpdate>? _connection;
  final Rx<BleConnectStatus> connectionStatus =
      BleConnectStatus.disconnected.obs;

  Rx<DiscoveredDevice?> connectedDevice = Rx<DiscoveredDevice?>(null);
  Rxn<Service> targetService = Rxn<Service>();
  List<Service> services = [];
  StreamSubscription? dataSubscription;
  ListQueue<double> receivedPPGDataQueue = ListQueue<double>();
  ListQueue<double> filteredPPGDataQueue = ListQueue<double>();
  ListQueue<List<double>> receivedACCDataQueue = ListQueue<List<double>>();
  ListQueue<List<double>> receivedGyroDataQueue = ListQueue<List<double>>();
  ListQueue<List<double>> receivedMagDataQueue = ListQueue<List<double>>();
  ListQueue<double> receivedBATTDataQueue = ListQueue<double>();
  ListQueue<double> receivedNewBATTDataQueue = ListQueue<double>();

  // Uuid
  final Uuid uartServiceUuid = Uuid.parse(NewertUUID().uartServiceUuid);
  final Uuid readUartCharacteristicUuid =
      Uuid.parse(NewertUUID().readUartCharacteristicUuid);
  final Uuid writeUartCharacteristicUuid =
      Uuid.parse(NewertUUID().writeUartCharacteristicUuid);

  final Uuid ppgServiceUuid = Uuid.parse(NewertUUID().ppgServiceUuid);
  final Uuid readPPGCharacteristicUuid =
      Uuid.parse(NewertUUID().readPPGCharacteristicUuid);

  final Uuid battServiceUuid = Uuid.parse(NewertUUID().battServiceUuid);
  final Uuid readBattCharacteristicUuid =
      Uuid.parse(NewertUUID().readBattCharacteristicUuid);

  Map<Uuid, List<Uuid>> serviceCharacteristicMap = {
    Uuid.parse(NewertUUID().uartServiceUuid): [
      Uuid.parse(NewertUUID().readUartCharacteristicUuid),
      Uuid.parse(NewertUUID().writeUartCharacteristicUuid)
    ],
    // PPG
    Uuid.parse(NewertUUID().ppgServiceUuid): [
      Uuid.parse(NewertUUID().readPPGCharacteristicUuid),
    ],
    // Battery
    Uuid.parse(NewertUUID().battServiceUuid): [
      Uuid.parse(NewertUUID().readBattCharacteristicUuid)
    ]
  };

  final ds = DataSource();

  @override
  void onInit() {
    super.onInit();
    _ble.statusStream.listen((status) {
      if (status == BleStatus.ready) {
        startScan();
      }
    });
  }

  @override
  void dispose() {
    receivedPPGDataQueue.clear();
    receivedACCDataQueue.clear();
    receivedGyroDataQueue.clear();
    receivedMagDataQueue.clear();

    super.dispose();
  }

  void startScan() {
    isScanning(true);
    devices.clear();
    try {
      _ble.scanForDevices(
        withServices: [uartServiceUuid, ppgServiceUuid, battServiceUuid],
        scanMode: ScanMode.lowLatency,
      ).listen((scanResult) {
        if (!devices.any((device) => device.id == scanResult.id)) {
          devices.add(scanResult);
        }
      }, onDone: stopScan);
    } catch (e) {
      print("Scan error $e");
    }
  }

  void stopScan() {
    isScanning(false);
  }

  Future<void> connectToDevice(DiscoveredDevice device) async {
    currentDevice = device;
    if (_connection != null) {
      _connection = null;
    }
    _connection = await _ble
        .connectToDevice(
            id: device.id, connectionTimeout: const Duration(seconds: 3))
        .listen((connectionState) {
      switch (connectionState.connectionState) {
        case DeviceConnectionState.connecting:
          connectionStatus.value = BleConnectStatus.connecting;
          break;
        case DeviceConnectionState.connected:
          connectionStatus.value = BleConnectStatus.connected;
          connectedDevice.value = device;

          _ble.requestMtu(deviceId: device.id, mtu: 100);
          _ble.requestConnectionPriority(
              deviceId: device.id,
              priority: ConnectionPriority.highPerformance);
          discoverServices(device);
          break;
        case DeviceConnectionState.disconnecting:
          connectionStatus.value = BleConnectStatus.disconnecting;
          break;
        case DeviceConnectionState.disconnected:
          connectionStatus.value = BleConnectStatus.disconnected;
          break;
      }
      print('_connectionStatus : $connectionStatus');
    }, onError: (e) {
      print('Connection error: $e');
    }).asFuture();
  }

  void _reconnect() {
    Future.delayed(Duration(seconds: 1), () {
      print("Try Reconnectiong...");
      connectToDevice(currentDevice!);
    });
  }

  void discoverServices(DiscoveredDevice device) async {
    final discoveredServices = await _ble.discoverServices(device.id);
    for (final service in discoveredServices) {
      if (serviceCharacteristicMap.containsKey(service.serviceId)) {
        discoverCharacteristics(service, device.id);
      }
    }
  }

  void discoverCharacteristics(DiscoveredService service, String deviceId) {
    for (final characteristic in service.characteristics) {
      if (serviceCharacteristicMap[service.serviceId]!
          .contains(characteristic.characteristicId)) {
        var qualifiedCharacteristic = QualifiedCharacteristic(
            serviceId: service.serviceId,
            characteristicId: characteristic.characteristicId,
            deviceId: deviceId);
        subscribeToCharacteristic(qualifiedCharacteristic);
      }
    }
  }

  void subscribeToCharacteristic(QualifiedCharacteristic characteristic) {
    // Convert the 32-bit integer representation back to float32
    Float32List float32List = Float32List(1);
    Int32List int32List = float32List.buffer.asInt32List();
    if (characteristic.characteristicId == readPPGCharacteristicUuid) {
      dataSubscription?.cancel();
      dataSubscription =
          _ble.subscribeToCharacteristic(characteristic).listen((data) {
        if (data[0] == 2 && data[1] == 81) {
          int new_batt = ds.transformBatt(data);
          receivedBATTDataQueue.add(new_batt.toDouble());
        } else {
          int ppg = ds.transformPPG(data);
          receivedPPGDataQueue.add(ppg.toDouble());

          int accXFloat32 = ds.transformAxis(data, 'accX');
          int32List[0] = accXFloat32;
          double acc_x = float32List[0];

          int accYFloat32 = ds.transformAxis(data, 'accY');
          int32List[0] = accYFloat32;
          double acc_y = float32List[0];

          int accZFloat32 = ds.transformAxis(data, 'accZ');
          int32List[0] = accZFloat32;
          double acc_z = float32List[0];

          int gyroXFloat32 = ds.transformAxis(data, 'gyroX');
          int32List[0] = gyroXFloat32;
          double gyro_x = float32List[0];

          int gyroYFloat32 = ds.transformAxis(data, 'gyroY');
          int32List[0] = gyroYFloat32;
          double gyro_y = float32List[0];

          int gyroZFloat32 = ds.transformAxis(data, 'gyroZ');
          int32List[0] = gyroZFloat32;
          double gyro_z = float32List[0];

          int magXFloat32 = ds.transformAxis(data, 'magX');
          int32List[0] = magXFloat32;
          double mag_x = float32List[0];

          int magYFloat32 = ds.transformAxis(data, 'magY');
          int32List[0] = magYFloat32;
          double mag_y = float32List[0];

          int magZFloat32 = ds.transformAxis(data, 'magZ');
          int32List[0] = magZFloat32;
          double mag_z = float32List[0];

          receivedACCDataQueue.add([acc_x, acc_y, acc_z]);
          receivedGyroDataQueue.add([gyro_x, gyro_y, gyro_z]);
          receivedMagDataQueue.add([mag_x, mag_y, mag_z]);
        }
      });
    }
  }

  void writeCMDToDevice(String cmd) async {
    if (connectedDevice.value == null) return;
    var qualifiedCharacteristic = QualifiedCharacteristic(
      serviceId: uartServiceUuid,
      characteristicId: writeUartCharacteristicUuid,
      deviceId: connectedDevice.value!.id,
    );

    List<int> dataToSend = setASCII(cmd);

    try {
      _ble.writeCharacteristicWithResponse(qualifiedCharacteristic,
          value: dataToSend);
      print('Data written to the device');
    } catch (e) {
      print('Error writing to the device in writeCMDToDevice: $e');
    }
  }

  void writeDataToDevice(String message) async {
    if (connectedDevice.value == null) return;
    var qualifiedCharacteristic = QualifiedCharacteristic(
      serviceId: uartServiceUuid,
      characteristicId: writeUartCharacteristicUuid,
      deviceId: connectedDevice.value!.id,
    );
    List<int> dataToSend = setASCII(message);
    try {
      await _ble.writeCharacteristicWithResponse(qualifiedCharacteristic,
          value: dataToSend);
      print('Data written to the device');
    } catch (e) {
      print('Error writing to the device in writeDataToDevice: $e');
    }
  }

  List<int> setASCII(String text) {
    List<int> ASCIIResult = [];
    for (int i = 0; i < text.length; i++) {
      int asciiCode = text.codeUnitAt(i);
      ASCIIResult.add(asciiCode);
    }

    return ASCIIResult;
  }

  @override
  void onClose() {
    stopScan();
    // disconnectFromDevice();
    super.onClose();
  }
}

```   

### BLE Screen
The BleScreen widget provides the user interface for scanning and connecting to BLE devices. It lists discovered devices and handles user interactions.
```   
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controller/bleController.dart';

class BleScreen extends StatelessWidget {
  final BleController bleController = Get.put(BleController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // UI components for scanning and displaying devices
          ],
        ),
      ),
    );
  }

  Widget listItem(DiscoveredDevice device) {
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFECECEC),
        borderRadius: BorderRadius.circular(30),
      ),
      child: ListTile(
        onTap: () => onTap(device),
        leading: leading(device),
        title: deviceName(device),
        subtitle: deviceMacAddress(device),
        trailing: deviceSignal(device),
      ),
    );
  }

  Widget deviceSignal(DiscoveredDevice device) {
    return Text(device.rssi.toString());
  }

  Widget deviceMacAddress(DiscoveredDevice device) {
    return Text(device.id);
  }

  Widget deviceName(DiscoveredDevice device) {
    String name = '';
    if (device.name.isNotEmpty) {
      name = device.name;
    } else {
      name = 'Unknown Device';
    }
    return Text(name);
  }

  Widget leading(DiscoveredDevice device) {
    return const CircleAvatar(
      backgroundColor: Color(0xFF24306B),
      child: Icon(
        Icons.bluetooth,
        color: Colors.white,
      ),
    );
  }

  void onTap(DiscoveredDevice device) async {
    bleController.connectToDevice(device);
    debugPrint("connection status ${bleController.connectionStatus}");

    if (bleController.connectionStatus == BleConnectStatus.connected) {
      Get.to(() => const MeasureScreen());
    } else {
      await Future.delayed(const Duration(milliseconds: 500));

      bleController.connectToDevice(device);
      debugPrint("connection status else ${bleController.connectionStatus}");

      Get.offAll(() => const MeasureScreen());
    }
  }

  var isButtonDisabled = false.obs;
  DateTime? retryTime;
  void startScan() {
    isButtonDisabled.value = true;
    bleController.writeCMDToDevice(CMD.REBOOT_PPG);

    try {
      bleController.startScan();
      Timer(const Duration(seconds: 5), () {
        isButtonDisabled.value = false;
      });
    } catch (e) {
      if (e is ScanThrottleException) {
        retryTime = e.suggestedRetryTime;

        final now = DateTime.now();
        final delay = retryTime!.difference(now);

        Timer(delay, () {
          isButtonDisabled.value = false;
          startScan();
        });
      } else {
        isButtonDisabled.value = false;
      }
    }
  }

  Future<void> _requestPermissions() async {
    PermissionStatus bluetoothSacn = await Permission.bluetoothScan.request();
    if (bluetoothSacn.isGranted) {
      print('bluetoothSacn permission granted');
    } else {
      print('bluetoothSacn permission denied');
    }

    PermissionStatus bluetoothConnect =
        await Permission.bluetoothConnect.request();
    if (bluetoothConnect.isGranted) {
      print('bluetoothConnect permission granted');
    } else {
      print('bluetoothConnect permission denied');
    }

    PermissionStatus bluetoothAdvertise =
        await Permission.bluetoothAdvertise.request();
    if (bluetoothAdvertise.isGranted) {
      print('bluetoothAdvertise permission granted');
    } else {
      print('bluetoothAdvertise permission denied');
    }
    PermissionStatus bluetoothState = await Permission.bluetooth.request();
    if (bluetoothState.isGranted) {
      print('bluetoothState permission granted');
    } else {
      print('bluetoothState permission denied');
    }

    PermissionStatus locationStatus = await Permission.location.request();
    if (locationStatus.isGranted) {
      print('Location permission granted');
    } else {
      print('Location permission denied');
    }
  }
}


```   


### Measure Screen
The MeasureScreen widget is used for displaying and recording data from the connected BLE device.
```   
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import '../controller/bleController.dart';
import '../view/style.dart';

class MeasureScreen extends StatefulWidget {
  const MeasureScreen({super.key});

  @override
  State<MeasureScreen> createState() => _MeasureScreenState();
}

class _MeasureScreenState extends State<MeasureScreen> {
  var bleController = Get.put(BleController());

  Timer? _dataTimer;

  RxBool isRecording = false.obs;
  DateTime startTime = DateTime.now();

  @override
  void initState() {
    _requestPermissions();
    super.initState();
  }

  Future<void> _requestPermissions() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
    }
  }

  @override
  void dispose() {
    _dataTimer?.cancel();
    super.dispose();
  }

  void _startGetDataTimer() {
    bleController.receivedPPGDataQueue.clear();
    bleController.receivedACCDataQueue.clear();
    bleController.receivedGyroDataQueue.clear();
    bleController.receivedMagDataQueue.clear();

    var dataSource = DataSource();

    _dataTimer =
        Timer.periodic(const Duration(milliseconds: 1000), (timer) async {
      List<double> ppgDataList = [];
      List<List<double>> accDataList = [];
      List<List<double>> gyroDataList = [];
      List<List<double>> magDataList = [];

      ppgDataList.addAll(bleController.receivedPPGDataQueue);
      bleController.receivedPPGDataQueue.clear();

      accDataList.addAll(bleController.receivedACCDataQueue);
      bleController.receivedACCDataQueue.clear();
      gyroDataList.addAll(bleController.receivedGyroDataQueue);
      bleController.receivedGyroDataQueue.clear();
      magDataList.addAll(bleController.receivedMagDataQueue);
      bleController.receivedMagDataQueue.clear();

      if (ppgDataList.isNotEmpty) {
        List<double> resultPPG = dataSource.getScalarData(ppgDataList, 50);
        List<List<double>> resultACC = dataSource.getAxisData(accDataList, 50);
        List<List<double>> resultGyro =
            dataSource.getAxisData(gyroDataList, 50);
        List<List<double>> resultMag = dataSource.getAxisData(magDataList, 50);

        debugPrint("PPG data for 1 seconds : $resultPPG");
        debugPrint("ACC data for 1 seconds: $resultACC");
        debugPrint("Gyro data for 1 seconds: $resultGyro");
        debugPrint("Mag data for 1 seconds: $resultMag");
      }
    });
  }

  void _stopTimer() {
    _dataTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) {
          return;
        }
        bool shouldExit = await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(20.0)),
              ),
              title: const Text('앱을 종료하시겠습니까?',
                  style: AppTextStyle.bodyRegularHyperlink),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.black54,
                  ),
                  child: const Text(
                    '취소',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.point,
                  ),
                  child: const Text(
                    '확인',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            );
          },
        );

        if (shouldExit) {
          bleController.writeCMDToDevice(CMD.STOP_PPG);
          bleController.writeCMDToDevice(CMD.REBOOT_PPG);
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              icon: const Icon(Icons.info),
              color: Colors.white,
              onPressed: () {
                showLicensePage(
                  context: context,
                  applicationName: 'VitalTrack',
                  applicationVersion: '1.0.0',
                );
              },
            ),
          ],
          centerTitle: true,
          elevation: 1,
          backgroundColor: AppColors.point,
          title: const Text("VitalTrack SDK"),
          titleTextStyle: AppTextStyle.subtitleLarge,
          leading: IconButton(
            onPressed: () async {
              bool shouldExit = await showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(20.0)),
                    ),
                    title: const Text('앱을 종료하시겠습니까?',
                        style: AppTextStyle.bodyRegularHyperlink),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(false);
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.black54,
                        ),
                        child: const Text(
                          '취소',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(true);
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.point,
                        ),
                        child: const Text(
                          '확인',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  );
                },
              );

              if (shouldExit) {
                bleController.writeCMDToDevice(CMD.STOP_PPG);
                bleController.writeCMDToDevice(CMD.REBOOT_PPG);
                SystemNavigator.pop();
              }
            },
            color: Colors.white,
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [],
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            if (isRecording.value) {
              startTime = DateTime.now();
              bleController.writeCMDToDevice(CMD.STOP_PPG);
              _stopTimer();
            } else {
              bleController.writeCMDToDevice(CMD.START_PPG);
              _startGetDataTimer();
            }
            isRecording.value = !isRecording.value;
          },
          backgroundColor: AppColors.point,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          elevation: 8,
          child: Obx(() {
            return Icon(
              isRecording.value ? Icons.stop : Icons.play_arrow,
              color: Colors.white,
              size: 50,
            );
          }),
        ),
      ),
    );
  }
}

```   

## Permissions
Ensure to request the necessary permissions for Bluetooth and location services. The BleScreen and MeasureScreen widgets include methods to request these permissions using the permission_handler package.

## Contributing
Contributions are welcome! Please submit pull requests or open issues for any bugs or feature requests.

## Requirements
Dart SDK >=2.12.0 <3.0.0
Flutter SDK >=2.0.0
Android API Level 21+

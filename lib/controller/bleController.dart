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

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:newert_vitaltrack/newert_vitaltrack.dart';
import 'package:permission_handler/permission_handler.dart';

class BleController extends GetxController with WidgetsBindingObserver {
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  var isScanning = false.obs;
  var devices = <DiscoveredDevice>[].obs;
  var connectedDevices = <DiscoveredDevice>[].obs;
  DiscoveredDevice? currentDevice;

  StreamSubscription<ConnectionStateUpdate>? connection;
  final Rx<BleConnectStatus> connectionStatus =
      BleConnectStatus.disconnected.obs;

  Rx<DiscoveredDevice?> connectedDevice = Rx<DiscoveredDevice?>(null);
  Rxn<Service> targetService = Rxn<Service>();
  List<Service> services = [];
  StreamSubscription? dataSubscription;
  double ppgValue = 0;
  double accXValue = 0;
  double accYValue = 0;
  double accZValue = 0;
  double batValue = 0;
  ListQueue<double> receivedPPGDataQueue = ListQueue<double>();
  ListQueue<double> filteredPPGDataQueue = ListQueue<double>();
  ListQueue<List<double>> receivedACCDataQueue = ListQueue<List<double>>();
  ListQueue<List<double>> receivedGyroDataQueue = ListQueue<List<double>>();
  ListQueue<List<double>> receivedMagDataQueue = ListQueue<List<double>>();
  ListQueue<double> receivedBATTDataQueue = ListQueue<double>();

  final Uuid uartServiceUuid =
      Uuid.parse("6e400001-b5a3-f393-e0a9-e50e24dcca9e");
  final Uuid readUartCharacteristicUuid =
      Uuid.parse("6e400003-b5a3-f393-e0a9-e50e24dcca9e");
  final Uuid writeUartCharacteristicUuid =
      Uuid.parse("6e400002-b5a3-f393-e0a9-e50e24dcca9e");

  final Uuid ppgServiceUuid =
      Uuid.parse('00001000-0000-1000-8000-00805f9b34fb');
  final Uuid readPPGCharacteristicUuid =
      Uuid.parse('00001100-0000-1000-8000-00805f9b34fb');
  final Uuid readCharacteristicUuid = Uuid.parse('1100');

  final Uuid battServiceUuid =
      Uuid.parse("0000180f-0000-1000-8000-00805f9b34fb");
  final Uuid readBattCharacteristicUuid =
      Uuid.parse("00002a19-0000-1000-8000-00805f9b34fb");

  Map<Uuid, List<Uuid>> serviceCharacteristicMap = {
    Uuid.parse("6e400001-b5a3-f393-e0a9-e50e24dcca9e"): [
      Uuid.parse("6e400003-b5a3-f393-e0a9-e50e24dcca9e"),
      Uuid.parse("6e400002-b5a3-f393-e0a9-e50e24dcca9e")
    ],
    // PPG
    Uuid.parse('00001000-0000-1000-8000-00805f9b34fb'): [
      Uuid.parse('00001100-0000-1000-8000-00805f9b34fb'),
    ],
    // Battery
    Uuid.parse("0000180f-0000-1000-8000-00805f9b34fb"): [
      Uuid.parse("00002a19-0000-1000-8000-00805f9b34fb")
    ]
  };

  int currentIndex = 0;
  List<int> currentData = [];
  final int sampleRate = 50; // 샘플링 레이트 (50Hz)
  final int chunkSize = 1; // 한 번에 처리할 데이터 청크 크기 (2바이트씩 4개)
  final int totalSamples = 200; // 전체 데이터 샘플 수

  List<int> decodeData = List.filled(40, 0);

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
    // if (currentDevice != null) _ble.clearGattCache(currentDevice!.id);

    isScanning(true);
    devices.clear();
    try {
      _ble.scanForDevices(
        withServices: [uartServiceUuid, ppgServiceUuid, battServiceUuid],
        scanMode: ScanMode.lowLatency,
      ).listen((scanResult) {
        if (!devices.any((device) => device.id == scanResult.id)) {
          devices.add(scanResult);
          print("$scanResult");
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
    print("v ${device.name}");

    currentDevice = device;
    if (connection != null) {
      connection = null;
    }

    connection = await _ble
        .connectToDevice(
            id: device.id, connectionTimeout: const Duration(seconds: 5))
        .listen((event) {
      switch (event.connectionState) {
        case DeviceConnectionState.connecting:
          connectionStatus.value = BleConnectStatus.connecting;
          break;
        case DeviceConnectionState.connected:
          connectionStatus.value = BleConnectStatus.connected;
          connectedDevice.value = device;

          _ble.requestMtu(deviceId: device.id, mtu: 100);

          discoverServices(device);
          break;
        case DeviceConnectionState.disconnecting:
          connectionStatus.value = BleConnectStatus.disconnecting;
          break;
        case DeviceConnectionState.disconnected:
          connectionStatus.value = BleConnectStatus.disconnected;
          break;
      }
    }, onError: (e) {
      print('Connection error: $e');
    }).asFuture();

    print("end coonnect ${connectionStatus.value}");
  }

  void _reconnect() {
    Future.delayed(Duration(seconds: 1), () {
      print("Try Reconnectiong...");
      connectToDevice(currentDevice!);
    });
  }

  void discoverServices(DiscoveredDevice device) async {
    final discoveredServices = await _ble.getDiscoveredServices(device.id);

    for (final service in discoveredServices) {
      discoverCharacteristics(service, device.id);
    }
  }

  void discoverCharacteristics(Service service, String deviceId) {
    for (final characteristic in service.characteristics) {
      var qualifiedCharacteristic = QualifiedCharacteristic(
          serviceId: service.id,
          characteristicId: characteristic.id,
          deviceId: deviceId);

      try {
        subscribeToCharacteristic(qualifiedCharacteristic);
      } catch (e) {
        print("e: $e");
      }
    }
  }

  void subscribeToCharacteristic(QualifiedCharacteristic characteristic) {
    // Convert the 32-bit integer representation back to float32
    Float32List float32List = Float32List(1);
    Int32List int32List = float32List.buffer.asInt32List();
    if (characteristic.characteristicId == readCharacteristicUuid) {
      dataSubscription?.cancel();
      dataSubscription =
          _ble.subscribeToCharacteristic(characteristic).listen((data) {
        // print("ble data len ${data.length} \nble data : $data");
        if (data[0] == 66 && data[1] == 65 && data[2] == 84 && data[3] == 84) {
          int batt = (data[5] << 8) | data[4];
          int newBatt = data[6];
          if (newBatt > 100) {
            newBatt = 100;
          } else if (newBatt < 0) {
            newBatt = 0;
          }
          receivedBATTDataQueue.add(newBatt.toDouble());
          print("batt ${batt.toDouble()}");
        } else {
          for (int i = 0; i < chunkSize; i++) {
            int ppg = ((data[20 * i + 1] << 8) | data[20 * i + 0]);
            receivedPPGDataQueue.add(ppg.toDouble());

            int accXFloat32 =
                float16To32((data[20 * i + 3] << 8) | data[20 * i + 2]);
            int32List[0] = accXFloat32;
            double acc_x = float32List[0];

            int accYFloat32 =
                float16To32((data[20 * i + 5] << 8) | data[20 * i + 4]);
            int32List[0] = accYFloat32;
            double acc_y = float32List[0];

            int accZFloat32 =
                float16To32((data[20 * i + 7] << 8) | data[20 * i + 6]);
            int32List[0] = accZFloat32;
            double acc_z = float32List[0];

            int gyroXFloat32 =
                float16To32((data[20 * i + 9] << 8) | data[20 * i + 8]);
            int32List[0] = gyroXFloat32;
            double gyro_x = float32List[0];

            int gyroYFloat32 =
                float16To32((data[20 * i + 11] << 8) | data[20 * i + 10]);
            int32List[0] = gyroYFloat32;
            double gyro_y = float32List[0];

            int gyroZFloat32 =
                float16To32((data[20 * i + 13] << 8) | data[20 * i + 12]);
            int32List[0] = gyroZFloat32;
            double gyro_z = float32List[0];

            int magXFloat32 =
                float16To32((data[20 * i + 15] << 8) | data[20 * i + 14]);
            int32List[0] = magXFloat32;
            double mag_x = float32List[0];

            int magYFloat32 =
                float16To32((data[20 * i + 17] << 8) | data[20 * i + 16]);
            int32List[0] = magYFloat32;
            double mag_y = float32List[0];

            int magZFloat32 =
                float16To32((data[20 * i + 19] << 8) | data[20 * i + 18]);
            int32List[0] = magZFloat32;
            double mag_z = float32List[0];

            receivedACCDataQueue.add([acc_x, acc_y, acc_z]);
            receivedGyroDataQueue.add([gyro_x, gyro_y, gyro_z]);
            receivedMagDataQueue.add([mag_x, mag_y, mag_z]);
          }
        }
      });
    }
  }

  int float16To32(int num) {
    // float 32bit : 1bit sign, 8bit exponent, 23bit fraction
    // float 16bit : 1bit sign, 5bit exponent, 10bit fraction
    int sign = (num << 16) & 0x80000000;
    int exponent = (num >> 10) & 0x1F;
    int fraction = num & 0x3FF;

    fraction = (fraction * 8192) & 0x7FFFFF; // 8192 = pow(2,23) / pow(2,10)

    if (exponent == 0) {
      exponent = 0x00;
    } else if (exponent == 0x1F) {
      exponent = 0xFF;
    } else {
      exponent -= 0xF;
      if (exponent < -15 || 16 < exponent) {
        // Error 범위 초과
        exponent = 0xFF;
        fraction = 0x00000000;
      } else {
        exponent += 0x7F;
      }
    }
    return (sign | (exponent << 23) | fraction);
  }

  static List<double> _processIMUData(List<int> data) {
    // print("imu data $data");
    // Acc
    String IEEE754ValueAccX = _convertStringTo2Bytes(data[5].toString()) +
        _convertStringTo2Bytes(data[4].toString()) +
        _convertStringTo2Bytes(data[3].toString()) +
        _convertStringTo2Bytes(data[2].toString());
    String IEEE754ValueAccY = _convertStringTo2Bytes(data[9].toString()) +
        _convertStringTo2Bytes(data[8].toString()) +
        _convertStringTo2Bytes(data[7].toString()) +
        _convertStringTo2Bytes(data[6].toString());
    String IEEE754ValueAccZ = _convertStringTo2Bytes(data[13].toString()) +
        _convertStringTo2Bytes(data[12].toString()) +
        _convertStringTo2Bytes(data[11].toString()) +
        _convertStringTo2Bytes(data[10].toString());

    double accXValue = _convertIEEE754ToDecimal(IEEE754ValueAccX);
    double accYValue = _convertIEEE754ToDecimal(IEEE754ValueAccY);
    double accZValue = _convertIEEE754ToDecimal(IEEE754ValueAccZ);

    // Gyro
    String IEEE754ValueGyroX = _convertStringTo2Bytes(data[17].toString()) +
        _convertStringTo2Bytes(data[16].toString()) +
        _convertStringTo2Bytes(data[15].toString()) +
        _convertStringTo2Bytes(data[14].toString());
    String IEEE754ValueGyroY = _convertStringTo2Bytes(data[21].toString()) +
        _convertStringTo2Bytes(data[20].toString()) +
        _convertStringTo2Bytes(data[19].toString()) +
        _convertStringTo2Bytes(data[18].toString());
    String IEEE754ValueGyroZ = _convertStringTo2Bytes(data[25].toString()) +
        _convertStringTo2Bytes(data[24].toString()) +
        _convertStringTo2Bytes(data[23].toString()) +
        _convertStringTo2Bytes(data[22].toString());

    double gyroXValue = _convertIEEE754ToDecimal(IEEE754ValueGyroX);
    double gyroYValue = _convertIEEE754ToDecimal(IEEE754ValueGyroY);
    double gyroZValue = _convertIEEE754ToDecimal(IEEE754ValueGyroZ);

    // Mag
    String IEEE754ValueMagX = _convertStringTo2Bytes(data[29].toString()) +
        _convertStringTo2Bytes(data[28].toString()) +
        _convertStringTo2Bytes(data[27].toString()) +
        _convertStringTo2Bytes(data[26].toString());
    String IEEE754ValueMagY = _convertStringTo2Bytes(data[33].toString()) +
        _convertStringTo2Bytes(data[32].toString()) +
        _convertStringTo2Bytes(data[31].toString()) +
        _convertStringTo2Bytes(data[30].toString());
    String IEEE754ValueMagZ = _convertStringTo2Bytes(data[37].toString()) +
        _convertStringTo2Bytes(data[36].toString()) +
        _convertStringTo2Bytes(data[35].toString()) +
        _convertStringTo2Bytes(data[34].toString());

    double magXValue = _convertIEEE754ToDecimal(IEEE754ValueMagX);
    double magYValue = _convertIEEE754ToDecimal(IEEE754ValueMagY);
    double magZValue = _convertIEEE754ToDecimal(IEEE754ValueMagZ);
    return [
      accXValue,
      accYValue,
      accZValue,
      gyroXValue,
      gyroYValue,
      gyroZValue,
      magXValue,
      magYValue,
      magZValue
    ];
  }

  static String _convertStringTo2Bytes(String decimalNumberStr) {
    int decimalNumber = int.parse(decimalNumberStr);
    String binaryString = decimalNumber.toRadixString(2);
    while (binaryString.length < 16) {
      binaryString = '0' + binaryString;
    }
    return binaryString.substring(8, 16);
  }

  static double _convertIEEE754ToDecimal(String ieee754Binary) {
    int sign = int.parse(ieee754Binary[0]);
    int exponent = int.parse(ieee754Binary.substring(1, 9), radix: 2);
    double fraction = 1.0;

    for (int i = 0; i < ieee754Binary.substring(9).length; i++) {
      fraction += int.parse(ieee754Binary[9 + i]) / (1 << (i + 1));
    }

    double decimalValue = sign == 0 ? 1.0 : -1.0;
    decimalValue *= fraction * pow(2, exponent - 127);

    return decimalValue;
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

class Float32Union {
  Float32Union();

  late ByteData _byteData = ByteData(4);

  // float 값을 설정
  set dataf(double value) {
    _byteData.setFloat32(0, value, Endian.little);
  }

  // float 값을 가져오기
  double get dataf => _byteData.getFloat32(0, Endian.little);

  // uint32_t 값을 설정
  set data32(int value) {
    _byteData.setUint32(0, value, Endian.little);
  }

  // uint32_t 값을 가져오기
  int get data32 => _byteData.getUint32(0, Endian.little);

  // uint8_t[4] 값을 설정 및 가져오기
  Uint8List get data8 {
    return _byteData.buffer.asUint8List();
  }

  set data8(Uint8List value) {
    if (value.length != 4) {
      throw ArgumentError('data8 must be a list of 4 bytes');
    }
    for (int i = 0; i < 4; i++) {
      _byteData.setUint8(i, value[i]);
    }
  }
}

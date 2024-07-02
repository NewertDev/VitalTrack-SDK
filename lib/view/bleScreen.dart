import 'dart:async';
import 'package:newert_vitaltrack/src/newert_vitaltrack.dart';

import '../view/style.dart';
import 'measureScreen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wrapped_korean_text/wrapped_korean_text.dart';
import '../controller/bleController.dart';

class BleScreen extends StatelessWidget {
  final BleController bleController = Get.put(BleController());

  BleScreen({super.key});

  /* 장치 아이템 위젯 */
  Widget listItem(DiscoveredDevice r) {
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFECECEC),
        borderRadius: BorderRadius.circular(30), //모서리를 둥글게
      ),
      child: ListTile(
        onTap: () => onTap(r),
        leading: leading(r),
        title: deviceName(r),
        subtitle: deviceMacAddress(r),
        trailing: deviceSignal(r),
      ),
    );
  }

  /*
   여기서부터는 장치별 출력용 함수들
  */
  /*  장치의 신호값 위젯  */
  Widget deviceSignal(DiscoveredDevice device) {
    return Text(device.rssi.toString());
  }

  /* 장치의 MAC 주소 위젯  */
  Widget deviceMacAddress(DiscoveredDevice device) {
    return Text(device.id);
  }

  /* 장치의 명 위젯  */
  Widget deviceName(DiscoveredDevice device) {
    String name = '';

    if (device.name.isNotEmpty) {
      // device.name에 값이 있다면
      name = device.name;
    } else {
      // 둘다 없다면 이름 알 수 없음...
      name = 'Unknown Device';
    }
    return Text(name);
  }

  /* BLE 아이콘 위젯 */
  Widget leading(DiscoveredDevice r) {
    return const CircleAvatar(
      backgroundColor: Color(0xFF24306B),
      child: Icon(
        Icons.bluetooth,
        color: Colors.white,
      ),
    );
  }

  /* 장치 아이템을 탭 했을때 호출 되는 함수 */
  void onTap(DiscoveredDevice device) async {
    bleController.connectToDevice(device);
    debugPrint("connection status ${bleController.connectionStatus}");

    if (bleController.connectionStatus == BleConnectStatus.connected) {
      Get.to(() => const MeasureScreen());
    } else {
      await Future.delayed(const Duration(milliseconds: 500));

      bleController.connectToDevice(device);
      debugPrint("connection status else ${bleController.connectionStatus}");

      // Get.to(() => const MeasureScreen());
      Get.offAll(() => const MeasureScreen());
    }
  }

  var isButtonDisabled = false.obs;
  DateTime? retryTime;
  void startScan() {
    isButtonDisabled.value = true;
    bleController.writeCMDToDevice(CMD.REBOOT_PPG);

    try {
      // BLE 스캔 시작
      bleController.startScan();

      // 스캔이 성공적으로 시작되면 버튼을 3초 동안 비활성화
      Timer(const Duration(seconds: 5), () {
        isButtonDisabled.value = false;
      });
    } catch (e) {
      // 특정 예외 처리
      if (e is ScanThrottleException) {
        retryTime = e.suggestedRetryTime;

        // 재시도 시간까지의 지연 시간 계산
        final now = DateTime.now();
        final delay = retryTime!.difference(now);

        Timer(delay, () {
          isButtonDisabled.value = false;
          startScan(); // 스캔 재시도
        });
      } else {
        // 필요한 경우 다른 예외 처리
        isButtonDisabled.value = false;
      }
    }
  }

  Future<void> _requestPermissions() async {
    // 블루투스 권한 요청
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

    // 위치 권한 요청
    PermissionStatus locationStatus = await Permission.location.request();
    if (locationStatus.isGranted) {
      print('Location permission granted');
    } else {
      print('Location permission denied');
    }
  }

  @override
  Widget build(BuildContext context) {
    print("state :  ${bleController.connectionStatus}");
    _requestPermissions();
    double width = MediaQuery.of(context).size.width;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      "Bluetooth Connect",
                      style: AppTextStyle.supportTitleMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MeasureScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      //"건너뛰기",
                      "",
                      selectionColor: Color(0xFF24306B),
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 10,
              ),
              const Text(
                "Please check the power of the VitalTrack equipment. Select VitalTrack equipment \nfrom the list below.",
              ),
              const Divider(
                height: 15,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Connectable Devices",
                      style: AppTextStyle.subtitleMedium,
                    ),
                    Container(
                      child: OutlinedButton(
                        onPressed: () {
                          isButtonDisabled.value ? null : startScan();
                        },
                        style: const ButtonStyle(
                          backgroundColor:
                              MaterialStatePropertyAll(AppColors.primary),
                          foregroundColor:
                              MaterialStatePropertyAll(Colors.white),
                        ),
                        child: const Icon(Icons.refresh),
                      ),
                    ),
                  ],
                ),
              ),
              Obx(
                () => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 5, 8, 15.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFECECEC),
                        borderRadius: BorderRadius.circular(8), //모서리를 둥글게
                      ),
                      child: bleController.connectionStatus.value ==
                              BleConnectStatus.disconnected
                          ? ListView.separated(
                              itemCount: bleController.devices.length,
                              itemBuilder: (context, index) {
                                return Container(
                                  child: listItem(bleController.devices[index]),
                                );
                              },
                              separatorBuilder:
                                  (BuildContext context, int index) {
                                return const Divider();
                              },
                            )
                          : Center(
                              child: CircularProgressIndicator(),
                            ),
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
      /* 장치 검색 or 검색 중지  */
    );
  }
}

class ScanThrottleException implements Exception {
  final DateTime suggestedRetryTime;
  ScanThrottleException(this.suggestedRetryTime);
}

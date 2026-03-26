import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class MockFlutterBluePlus {
  static Stream<List<ScanResult>> scanResults = const Stream.empty();
  static Stream<bool> isScanning = const Stream.empty();
  static Stream<BluetoothAdapterState> adapterState = const Stream.empty();

  static Future<void> startScan({Duration? timeout}) async {}
  static Future<void> stopScan() async {}
  static Future<List<BluetoothDevice>> connectedDevices() async => [];
}
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  bool _isScanning = false;
  bool _isConnected = false;
  List<BluetoothDevice> _devices = [];

  @override
  void initState() {
    super.initState();
    _setupBluetoothListeners();
  }

  void _setupBluetoothListeners() {
    FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        _devices = results.map((r) => r.device).toList();
      });
    });

    FlutterBluePlus.isScanning.listen((isScanning) {
      setState(() {
        _isScanning = isScanning;
      });
    });
  }

  void _startScan() async {
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    } catch (e) {
      print('Scan error: $e');
    }
  }

  void _stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      print('Stop scan error: $e');
    }
  }

  void _connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      setState(() {
        _isConnected = true;
      });
      _stopScan();
    } catch (e) {
      print('Connection error: $e');
    }
  }

  void _disconnectDevice() async {
    try {
      await FlutterBluePlus.stopScan();
      setState(() {
        _isConnected = false;
        _devices.clear();
      });
    } catch (e) {
      print('Disconnect error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildBody();
  }

  Widget _buildBody() {
    if (_isConnected) {
      return _buildConnectedState();
    } else {
      return _buildDisconnectedState();
    }
  }

  Widget _buildDisconnectedState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _isScanning ? _stopScan : _startScan,
          child: Column(
            children: [
              Image.asset(
                'assets/images/Search.png',
                width: 120,
                height: 120,
              ),
              const SizedBox(height: 20),
              Text(
                _isScanning ? 'Scanning...' : 'Search devices',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        if (_devices.isNotEmpty) _buildDeviceList(),
      ],
    );
  }

  Widget _buildConnectedState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Column(
          children: [
            const Text(
              'Device connected',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Exercise Identifying...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            Image.asset(
              'assets/images/Identify.png',
              width: 120,
              height: 120,
            ),
          ],
        ),
        const SizedBox(height: 40),
        ElevatedButton(
          onPressed: _disconnectDevice,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
          ),
          child: const Text(
            'Disconnect',
            style: TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceList() {
    return Expanded(
      child: ListView.builder(
        itemCount: _devices.length,
        itemBuilder: (context, index) {
          final device = _devices[index];
          return ListTile(
            leading: const Icon(Icons.bluetooth),
            title: Text(device.platformName.isEmpty ? 'Unknown Device' : device.platformName),
            subtitle: Text(device.remoteId.str),
            trailing: ElevatedButton(
              onPressed: () => _connectToDevice(device),
              child: const Text('Connect'),
            ),
          );
        },
      ),
    );
  }
}
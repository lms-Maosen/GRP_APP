import 'dart:io';
import 'dart:async';
import 'package:csv/csv.dart';

// 1. Utility function: safely convert to double (error tolerant)
double safeParseDouble(dynamic value) {
  try {
    return double.parse(value.toString());
  } catch (e) {
    print("Data conversion error: $value");
    return 0.0;
  }
}

// 2. Utility function: read filtered data (Windows compatible)
Future<List<List<dynamic>>> readFilteredCsv(String filePath) async {
  final inputFile = File(filePath);
  if (!await inputFile.exists()) {
    throw FileSystemException("Filtered data file not found, please check the path: $filePath");
  }
  final inputCsv = await inputFile.readAsString();
  return const CsvToListConverter().convert(inputCsv);
}

// 3. Core class: wristband running distance counter (adjusted thresholds + smoothing parameters to solve under‑counting)
class WristRunningCounter {
  int _swingCycle = 0;        // Arm swing cycle count
  bool _isPeakDetected = false; // Flag for forward swing peak

  // Adjusted thresholds to be more lenient (adapt to actual arm swing, reduce under‑counting)
  double swingPeakThreshold;   // Forward swing peak: 1.0 (originally 1.3, more lenient)
  double swingValleyThreshold; // Backward swing valley: -0.8 (originally -1.1, more lenient)

  // Adjusted smoothing parameters for faster response
  final List<double> _dataBuffer = [];
  final int _bufferSize = 3;    // Window size from 5 → 3, faster response
  final int _minInterval = 3;   // Interval from 6 → 3, adapts to higher swing frequency
  int _sampleCounter = 0;

  // Constructor: initialise adjusted thresholds
  WristRunningCounter({
    double swingPeakThreshold = 0.8,
    double swingValleyThreshold = -0.5,
  })  : swingPeakThreshold = swingPeakThreshold,
        swingValleyThreshold = swingValleyThreshold;

  // Get total distance (1 cycle = 1.6 meters, logic unchanged)
  double get totalDistance => _swingCycle * 1.6;

  // Core: X‑axis swing cycle detection (logic unchanged, only parameters adjusted)
  void countSwingCycleByXAxis(double xValue) {
    _dataBuffer.add(xValue);
    if (_dataBuffer.length > _bufferSize) _dataBuffer.removeAt(0);
    if (_dataBuffer.length < _bufferSize) return;

    double avgX = _dataBuffer.reduce((a, b) => a + b) / _bufferSize;
    _sampleCounter++;

    // Swing cycle detection (more lenient thresholds to reduce under‑counting)
    if (avgX > swingPeakThreshold && !_isPeakDetected && _sampleCounter >= _minInterval) {
      _isPeakDetected = true;
      _sampleCounter = 0;
    } else if (avgX < swingValleyThreshold && _isPeakDetected && _sampleCounter >= _minInterval) {
      _swingCycle++;
      _isPeakDetected = false;
      _sampleCounter = 0;
    }
  }

  // Reset count
  void resetCount() {
    _swingCycle = 0;
    _isPeakDetected = false;
    _dataBuffer.clear();
    _sampleCounter = 0;
  }

  // Fine‑tune thresholds (can be adjusted manually)
  void adjustThreshold({double? newPeak, double? newValley}) {
    if (newPeak != null) swingPeakThreshold = newPeak;
    if (newValley != null) swingValleyThreshold = newValley;
    resetCount();
  }
}

// 4. Execution method: calculate final distance
Future<void> calculateRunningDistance(String filePath) async {
  final runningCounter = WristRunningCounter();

  print("Reading filtered_data.csv data...");
  final rows = await readFilteredCsv(filePath);
  if (rows.length <= 1) {
    print("Data is empty or only header, cannot calculate distance.");
    return;
  }

  // Print X‑axis characteristics to verify thresholds
  double xMin = double.infinity;
  double xMax = -double.infinity;
  for (int i = 1; i < rows.length; i++) {
    double x = safeParseDouble(rows[i][1]);
    if (x < xMin) xMin = x;
    if (x > xMax) xMax = x;
  }
  print("\n=== Filtered Data X‑Axis Characteristics ===");
  print("X‑axis range: min=$xMin, max=$xMax");
  print("Current thresholds: swingPeak=${runningCounter.swingPeakThreshold}, swingValley=${runningCounter.swingValleyThreshold}\n");

  print("Calculating running distance...");
  for (int i = 1; i < rows.length; i++) {
    final xValue = safeParseDouble(rows[i][1]);
    runningCounter.countSwingCycleByXAxis(xValue);
  }

  print("\n=====================");
  print("Running distance calculation complete!");
  print("Total arm swing cycles: ${runningCounter._swingCycle}");
  print("Final running distance: ${runningCounter.totalDistance.toStringAsFixed(1)} meters");
  print("=====================");
}

// 5. Entry point
void main() async {
  const csvPath = 'filtered_data.csv';
  try {
    await calculateRunningDistance(csvPath);
  } catch (e) {
    print("Distance calculation failed: $e");
  }
}
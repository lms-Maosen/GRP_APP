import 'dart:io';
import 'dart:async';
import 'package:csv/csv.dart';
import 'dart:math';

// Safely convert string to double, return 0.0 on failure
double safeParseDouble(dynamic value) {
  try {
    return double.parse(value.toString());
  } catch (e) {
    print("Cannot convert to number: $value");
    return 0.0;
  }
}

// Read CSV file and apply data processing
Future<List<List<dynamic>>> readCsv(String filePath) async {
  final inputFile = File(filePath);
  final inputCsv = await inputFile.readAsString();
  return const CsvToListConverter().convert(inputCsv);
}

class SquatCounter {
  int _count = 0;
  bool _isPeakDetected = false;

  // Set thresholds
  double peakThreshold;   // Set peak threshold (when standing up)
  double valleyThreshold; // Set valley threshold (when squatting down)

  // Cache data and minimum interval
  final List<double> _dataBuffer = [];
  final int _bufferSize = 10;  // Buffer window
  int _sampleCounter = 0;
  final int _minInterval = 15; // Minimum interval

  SquatCounter({
    double peakThreshold = 7.5,
    double valleyThreshold = 6.0,
  })  : peakThreshold = peakThreshold,
        valleyThreshold = valleyThreshold;

  int get count => _count;

  // Update count in real time
  void countBySingleAxis(double filteredValue) {
    _dataBuffer.add(filteredValue);
    if (_dataBuffer.length > _bufferSize) _dataBuffer.removeAt(0);
    if (_dataBuffer.length < _bufferSize) return;

    double avgValue = _dataBuffer.reduce((a, b) => a + b) / _bufferSize;
    _sampleCounter++;

    // Determine squat phase
    if (avgValue < peakThreshold && !_isPeakDetected && _sampleCounter >= _minInterval) {
      _isPeakDetected = true;  // Enter squat phase
      _sampleCounter = 0;      // Reset counter
    } else if (avgValue > valleyThreshold && _isPeakDetected && _sampleCounter >= _minInterval) {
      _count++;  // Complete one squat
      _isPeakDetected = false; // Exit squat state
      _sampleCounter = 0;      // Reset counter
    }
  }

  // Process three-axis acceleration data
  void countBy3Axis(Map<String, double> filtered3Axis) {
    double zValue = filtered3Axis['z'] ?? 0.0;
    countBySingleAxis(zValue);
  }

  void resetCount() {
    _count = 0;
    _isPeakDetected = false;
    _dataBuffer.clear();
    _sampleCounter = 0;
  }

  void adjustThreshold({double? newPeak, double? newValley}) {
    if (newPeak != null) peakThreshold = newPeak;
    if (newValley != null) valleyThreshold = newValley;
    resetCount();
  }
}

// Real-time squat counter (modified printing logic)
Future<void> startRealTimeSquatCounting(String filePath) async {
  SquatCounter squatCounter = SquatCounter(peakThreshold: 7.5, valleyThreshold: 6.0);
  // Core modification 1: Add variable to record previous count, initial 0
  int lastCount = 0;

  // Read CSV data (simulate real-time data stream)
  List<List<dynamic>> rows = await readCsv(filePath);

  // Iterate through each row and update count
  for (int i = 1; i < rows.length; i++) {
    double filteredZAcceleration = safeParseDouble(rows[i][3]);
    squatCounter.countBySingleAxis(filteredZAcceleration);

    // Core modification 2: Print only when count increases (new squat completed)
    int currentCount = squatCounter.count;
    if (currentCount > lastCount) {
      print("Real-time squat count: $currentCount");
      // To simulate real movement interval, keep the delay (milliseconds recommended to avoid lag)
      // await Future.delayed(Duration(milliseconds: 100));
      // Update previous count to avoid duplicate printing
      lastCount = currentCount;
    }
  }

  // Output final total count
  print("\nFinal squat count: ${squatCounter.count}");
}

void main() async {
  String filePath = 'filtered_data.csv';
  await startRealTimeSquatCounting(filePath); // Real-time counting
}
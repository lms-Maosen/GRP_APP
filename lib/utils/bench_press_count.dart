import 'dart:io';
import 'dart:async';
import 'package:csv/csv.dart';

// 1. Utility function: safely convert to double (error tolerant, prevents crash from dirty data)
double safeParseDouble(dynamic value) {
  try {
    return double.parse(value.toString());
  } catch (e) {
    print("Data conversion error: $value");
    return 0.0;
  }
}

// 2. Utility function: read bench press CSV data (Windows compatible, relative path)
Future<List<List<dynamic>>> readBenchPressCsv(String filePath) async {
  final inputFile = File(filePath);
  if (!await inputFile.exists()) {
    throw FileSystemException("Bench press data file not found, please check the path: $filePath");
  }
  final inputCsv = await inputFile.readAsString();
  return const CsvToListConverter().convert(inputCsv);
}

// 3. Core class: bench press counter (adapted for bench press movement, debounce + smoothing)
class BenchPressCounter {
  int _count = 0;          // Total bench press count
  bool _isLowered = false; // Flag indicating whether the barbell is in the lowered state (differentiates movement phases)

  // Bench press specific thresholds (based on data calibration)
  double valleyThreshold;  // Valley threshold (barbell descent: below this value indicates start of descent)
  double peakThreshold;    // Peak threshold (barbell ascent: above this value indicates completion of one rep)

  // Data buffer: smooths sensor fluctuations (10 sample window, avoids single jitter false positives)
  final List<double> _dataBuffer = [];
  final int _bufferSize = 10;
  int _sampleCounter = 0; // Sample interval counter
  final int _minInterval = 12; // Minimum interval between bench press movements (avoids false positives from rapid fluctuations)

  // Constructor: initialise bench press thresholds (default values remain unchanged)
  BenchPressCounter({
    double valleyThreshold = -1.5,
    double peakThreshold = 0.3,
  })  : valleyThreshold = valleyThreshold,
        peakThreshold = peakThreshold;

  int get count => _count;

  // 4. Core method: single‑axis (Z‑axis) bench press counting logic
  void countByZAxis(double filteredZValue) {
    // Step 1: buffer data, maintain window size (smoothing)
    _dataBuffer.add(filteredZValue);
    if (_dataBuffer.length > _bufferSize) _dataBuffer.removeAt(0);
    if (_dataBuffer.length < _bufferSize) return; // Wait until buffer is full to avoid false triggers

    // Step 2: calculate moving average (filter sensor noise)
    double avgZValue = _dataBuffer.reduce((a, b) => a + b) / _bufferSize;
    _sampleCounter++;

    // Step 3: detect full bench press cycle (descent → ascent)
    // Case 1: barbell descent (average below valley threshold and not already in lowered state)
    if (avgZValue < valleyThreshold && !_isLowered && _sampleCounter >= _minInterval) {
      _isLowered = true;       // Mark as lowered
      _sampleCounter = 0;      // Reset interval counter
    }
    // Case 2: barbell ascent (average above peak threshold and was in lowered state → one rep completed)
    else if (avgZValue > peakThreshold && _isLowered && _sampleCounter >= _minInterval) {
      _count++;
      _isLowered = false;
      _sampleCounter = 0;
    }
  }

  // 5. Helper method: reset count (use when restarting counting)
  void resetCount() {
    _count = 0;
    _isLowered = false;
    _dataBuffer.clear();
    _sampleCounter = 0;
  }

  void reset() => resetCount();

  // 6. Helper method: adjust thresholds (adapt to different users / devices)
  void adjustThreshold({double? newValley, double? newPeak}) {
    if (newValley != null) valleyThreshold = newValley;
    if (newPeak != null) peakThreshold = newPeak;
    resetCount();
  }
}

// 7. Execution method: read bench press data and count in real time (print each completed rep, no spamming)
Future<void> startBenchPressCounting(String filePath) async {
  final benchCounter = BenchPressCounter(
      valleyThreshold: -1.5,
      peakThreshold: 0.3
  );
  int lastCount = 0; // Track previous count to avoid duplicate printing (core: only print when count increments)

  // Read bench press CSV data
  print("Reading bench press data...");
  final rows = await readBenchPressCsv(filePath);
  if (rows.length <= 1) {
    print("Data is empty or only header, cannot count.");
    return;
  }

  // Iterate through data and count in real time (skip header, start from row 2)
  print("Starting bench press counting (print each completed rep)...\n");
  for (int i = 1; i < rows.length; i++) {
    // Read Z‑axis acceleration data (column 4, index 3 – same as squat code)
    final zValue = safeParseDouble(rows[i][3]);
    // Update count in real time
    benchCounter.countByZAxis(zValue);

    // Only print when a new bench press rep is completed (avoids spamming, same logic as squat code)
    final currentCount = benchCounter.count;
    if (currentCount > lastCount) {
      print("Real‑time bench press count: $currentCount");
      lastCount = currentCount;
      // Optional: simulate real movement interval (each rep ~1 second, can keep delay or remove)
      // await Future.delayed(const Duration(milliseconds: 800));
    }
  }

  // Output final result
  print("\n=====================");
  print("Bench press counting finished. Final count: ${benchCounter.count}");
  print("=====================");
}

// 8. Entry point: run bench press counting (Windows compatible, relative path)
void main() async {
  // Use relative path, read filtered_data.csv from current directory (same as squat code)
  const csvPath = 'filtered_data.csv';
  try {
    await startBenchPressCounting(csvPath);
  } catch (e) {
    print("Counting failed: $e");
  }
}
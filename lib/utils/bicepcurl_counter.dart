import 'dart:math';

class ExerciseCounter {
  int _count = 0;
  // 1. Significantly relax the threshold to make it easier to trigger.
  double peakThreshold;
  double valleyThreshold;
  bool _isPeakDetected = false;

  // 2. Reduce the buffer window, lower the smoothness, and become more sensitive to changes.
  final List<double> _dataBuffer = [];
  final int _bufferSize = 10;

  // 3. Shorten the minimum interval to allow faster consecutive actions.
  int _sampleCounter = 0;
  final int _minInterval = 15;

  ExerciseCounter({
    double peakThreshold = -3.0,
    double valleyThreshold = -1.5,
  })  : peakThreshold = peakThreshold,
        valleyThreshold = valleyThreshold;

  int get count => _count;

  void countBySingleAxis(double filteredValue) {
    _dataBuffer.add(filteredValue);
    if (_dataBuffer.length > _bufferSize) _dataBuffer.removeAt(0);
    if (_dataBuffer.length < _bufferSize) return;

    double avgValue = _dataBuffer.reduce((a, b) => a + b) / _bufferSize;
    _sampleCounter++;

    if (avgValue < peakThreshold && !_isPeakDetected && _sampleCounter >= _minInterval) {
      _isPeakDetected = true;
      _sampleCounter = 0;
    } else if (avgValue > valleyThreshold && _isPeakDetected && _sampleCounter >= _minInterval) {
      _count++;
      _isPeakDetected = false;
      _sampleCounter = 0;
    }
  }

  void countBy3Axis(Map<String, double> filtered3Axis) {
    double zValue = filtered3Axis['z'] ?? 0.0;
    countBySingleAxis(zValue);
  }

  double calculateTotalAcceleration(double x, double y, double z) {
    return sqrt(x * x + y * y + z * z);
  }

  void batchCount(List<double> filteredDataList) {
    for (double value in filteredDataList) {
      countBySingleAxis(value);
    }
  }

  void resetCount() {
    _count = 0;
    _isPeakDetected = false;
    _dataBuffer.clear();
    _sampleCounter = 0;
  }

  void reset() {
    resetCount();
  }

  void adjustThreshold({double? newPeak, double? newValley}) {
    if (newPeak != null) peakThreshold = newPeak;
    if (newValley != null) valleyThreshold = newValley;
    resetCount();
  }
}
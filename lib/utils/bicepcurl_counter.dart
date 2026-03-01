import 'dart:math';

class ExerciseCounter {
  int _count = 0;
  // 1. 大幅放宽阈值，更容易触发
  double peakThreshold;   // 从-4.0调至-3.0，更接近0，更容易触发峰值
  double valleyThreshold; // 从-2.0调至-1.5，更接近0，更容易触发谷值
  bool _isPeakDetected = false;

  // 2. 减小缓存窗口，降低平滑度，对变化更敏感
  final List<double> _dataBuffer = [];
  final int _bufferSize = 10; // 从20调至10，约96ms

  // 3. 缩短最小间隔，允许更快的连续动作
  int _sampleCounter = 0;
  final int _minInterval = 15; // 从30调至15，约144ms

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

    // 判定逻辑不变，仅参数放宽
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

  void adjustThreshold({double? newPeak, double? newValley}) {
    if (newPeak != null) peakThreshold = newPeak;
    if (newValley != null) valleyThreshold = newValley;
    resetCount();
  }
}
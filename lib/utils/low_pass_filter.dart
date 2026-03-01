/// 一阶IIR低通滤波工具类（稳定无NaN，适配运动计数）
/// 核心公式：y[n] = y[n-1] + α*(x[n] - y[n-1])
/// α = 2π*cutoff/fs （截止频率5Hz，采样率104Hz时α≈0.301）
class FirstOrderLowPassFilter {
  // 滤波系数α（0-1，值越小滤波效果越强）
  final double alpha;
  // 上一次滤波后的值（三轴）
  double _lastX = 0.0;
  double _lastY = 0.0;
  double _lastZ = 0.0;
  // 标记是否是第一个数据（避免初始值偏差）
  bool _isFirstData = true;

  /// 构造方法
  /// [cutoff] 截止频率（默认5Hz）
  /// [fs] 采样频率（默认104Hz）
  FirstOrderLowPassFilter({double cutoff = 5.0, double fs = 104.0}) :
        alpha = 2 * 3.1415926 * cutoff / fs; // 自动计算α，无需手动调参

  /// 对单轴数据实时滤波（适合逐帧处理传感器数据）
  double filterSingle(double rawValue, String axis) {
    if (_isFirstData) {
      // 第一个数据直接赋值，无滤波计算
      switch(axis) {
        case 'x': _lastX = rawValue; break;
        case 'y': _lastY = rawValue; break;
        case 'z': _lastZ = rawValue; break;
      }
      if (axis == 'z') _isFirstData = false; // 三轴都初始化后标记完成
      return rawValue;
    }

    // 核心滤波公式
    double filteredValue;
    switch(axis) {
      case 'x':
        filteredValue = _lastX + alpha * (rawValue - _lastX);
        _lastX = filteredValue;
        break;
      case 'y':
        filteredValue = _lastY + alpha * (rawValue - _lastY);
        _lastY = filteredValue;
        break;
      case 'z':
        filteredValue = _lastZ + alpha * (rawValue - _lastZ);
        _lastZ = filteredValue;
        break;
      default: filteredValue = rawValue;
    }
    return filteredValue;
  }

  /// 对单轴数据批量滤波（适合CSV离线测试）
  List<double> filterBatch(List<double> rawData, String axis) {
    List<double> filteredData = [];
    for (double value in rawData) {
      filteredData.add(filterSingle(value, axis));
    }
    return filteredData;
  }

  /// 对三轴数据批量滤波
  Map<String, List<double>> filter3Axis({
    required List<double> xData,
    required List<double> yData,
    required List<double> zData,
  }) {
    return {
      'x': filterBatch(xData, 'x'),
      'y': filterBatch(yData, 'y'),
      'z': filterBatch(zData, 'z'),
    };
  }

  /// 重置滤波状态
  void reset() {
    _lastX = 0.0;
    _lastY = 0.0;
    _lastZ = 0.0;
    _isFirstData = true;
  }
}
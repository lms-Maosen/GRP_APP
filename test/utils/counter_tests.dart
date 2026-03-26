import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fitness_pod/utils/bicepcurl_counter.dart';
import 'package:smart_fitness_pod/utils/bench_press_count.dart';
import 'package:smart_fitness_pod/utils/test_running_count.dart';

void main() {
  group('Bicep Curl Counter Tests', () {
    late ExerciseCounter counter;

    setUp(() {
      counter = ExerciseCounter(peakThreshold: -3.0, valleyThreshold: -1.5);
    });

    test('Should count a single repetition', () {
      // Simulate one curl cycle
      counter.countBySingleAxis(-4.0); // Peak
      counter.countBySingleAxis(-2.0); // Valley
      expect(counter.count, 1);
    });

    test('Should ignore noise below threshold', () {
      counter.countBySingleAxis(-1.0);
      counter.countBySingleAxis(-0.5);
      expect(counter.count, 0);
    });

    test('Reset should clear count', () {
      counter.countBySingleAxis(-4.0);
      counter.countBySingleAxis(-2.0);
      expect(counter.count, 1);

      counter.resetCount();
      expect(counter.count, 0);
    });
  });

  group('Bench Press Counter Tests', () {
    late BenchPressCounter counter;

    setUp(() {
      counter = BenchPressCounter(valleyThreshold: -1.5, peakThreshold: 0.3);
    });

    test('Should count a single press', () {
      counter.countByZAxis(-2.0); // Descent
      counter.countByZAxis(0.5);  // Ascent
      expect(counter.count, 1);
    });

    test('Should require proper sequence', () {
      counter.countByZAxis(0.5);
      counter.countByZAxis(-2.0);
      expect(counter.count, 0);
    });
  });

  group('Running Counter Tests', () {
    late WristRunningCounter counter;

    setUp(() {
      counter = WristRunningCounter(swingPeakThreshold: 0.8, swingValleyThreshold: -0.5);
    });

    test('Should count a swing cycle', () {
      counter.countSwingCycleByXAxis(1.0);
      counter.countSwingCycleByXAxis(-0.6);
      expect(counter.totalDistance, 1.6);
    });

    test('Distance should be proportional to cycles', () {
      counter.countSwingCycleByXAxis(1.0);
      counter.countSwingCycleByXAxis(-0.6);
      counter.countSwingCycleByXAxis(1.0);
      counter.countSwingCycleByXAxis(-0.6);
      expect(counter.totalDistance, 3.2);
    });
  });
}
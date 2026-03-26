import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fitness_pod/providers/history_provider.dart';

void main() {
  group('HistoryProvider Tests', () {
    late HistoryProvider historyProvider;

    setUp(() {
      historyProvider = HistoryProvider();
    });

    test('Initial sessions should be empty', () {
      expect(historyProvider.sessions, isEmpty);
    });

    test('addSession should add a workout session', () {
      final session = WorkoutSession(
        date: DateTime.now(),
        exercises: [
          ExerciseSet(exerciseName: 'squat', reps: 10, sets: 3),
        ],
      );

      historyProvider.addSession(session);

      expect(historyProvider.sessions.length, 1);
      expect(historyProvider.sessions.first.exercises.length, 1);
    });

    test('Merging of same exercise and reps across sessions on same day', () {
      final date = DateTime.now();
      final session1 = WorkoutSession(
        date: date,
        exercises: [ExerciseSet(exerciseName: 'squat', reps: 10, sets: 2)],
      );
      final session2 = WorkoutSession(
        date: date,
        exercises: [ExerciseSet(exerciseName: 'squat', reps: 10, sets: 1)],
      );

      historyProvider.addSession(session1);
      historyProvider.addSession(session2);

      final grouped = historyProvider.groupedByDate;
      final exercisesOnDate = grouped[DateTime(date.year, date.month, date.day)];

      expect(exercisesOnDate!.length, 1);
      expect(exercisesOnDate.first.sets, 3);
    });

    test('groupedByDate should group sessions by date', () {
      final today = DateTime.now();
      final yesterday = DateTime.now().subtract(const Duration(days: 1));

      historyProvider.addSession(WorkoutSession(
        date: today,
        exercises: [ExerciseSet(exerciseName: 'squat', reps: 10, sets: 2)],
      ));

      historyProvider.addSession(WorkoutSession(
        date: yesterday,
        exercises: [ExerciseSet(exerciseName: 'bench', reps: 8, sets: 3)],
      ));

      final grouped = historyProvider.groupedByDate;

      expect(grouped.keys.length, 2);
    });

    test('clearHistory should remove all sessions', () {
      historyProvider.addSession(WorkoutSession(
        date: DateTime.now(),
        exercises: [ExerciseSet(exerciseName: 'squat', reps: 10, sets: 2)],
      ));

      historyProvider.clearHistory();

      expect(historyProvider.sessions, isEmpty);
    });
  });
}
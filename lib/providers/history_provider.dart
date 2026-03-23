import 'package:flutter/material.dart';

// A set of records of the same exercise with the same number of repetitions.
class ExerciseSet {
  final String exerciseName;
  final int reps;
  int sets;

  ExerciseSet({required this.exerciseName, required this.reps, this.sets = 1});

  Map<String, dynamic> toJson() => {
    'exerciseName': exerciseName,
    'reps': reps,
    'sets': sets,
  };

  factory ExerciseSet.fromJson(Map<String, dynamic> json) {
    return ExerciseSet(
      exerciseName: json['exerciseName'],
      reps: json['reps'],
      sets: json['sets'],
    );
  }

  void addSet(int count) => sets += count;
}

// All exercise groups within a disconnection session.
class WorkoutSession {
  final DateTime date;
  final List<ExerciseSet> exercises;

  WorkoutSession({required this.date, required this.exercises});

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'exercises': exercises.map((e) => e.toJson()).toList(),
  };

  factory WorkoutSession.fromJson(Map<String, dynamic> json) {
    return WorkoutSession(
      date: DateTime.parse(json['date']),
      exercises: (json['exercises'] as List)
          .map((e) => ExerciseSet.fromJson(e))
          .toList(),
    );
  }
}

class HistoryProvider extends ChangeNotifier {
  List<WorkoutSession> _sessions = [];

  List<WorkoutSession> get sessions => _sessions;

  // Group by date and merge groups with the same exercise and the same number of repetitions.
  Map<DateTime, List<ExerciseSet>> get groupedByDate {
    Map<DateTime, List<ExerciseSet>> map = {};
    for (var session in _sessions) {
      DateTime key = DateTime(session.date.year, session.date.month, session.date.day);
      if (!map.containsKey(key)) map[key] = [];
      map[key] = _mergeExerciseSets(map[key]! + session.exercises);
    }
    return map;
  }

  List<ExerciseSet> _mergeExerciseSets(List<ExerciseSet> list) {
    Map<String, ExerciseSet> merged = {};
    for (var set in list) {
      String id = '${set.exerciseName}_${set.reps}';
      if (merged.containsKey(id)) {
        merged[id]!.addSet(set.sets);
      } else {
        merged[id] = ExerciseSet(
          exerciseName: set.exerciseName,
          reps: set.reps,
          sets: set.sets,
        );
      }
    }
    return merged.values.toList();
  }

  void addSession(WorkoutSession session) {
    _sessions.add(session);
    notifyListeners();
  }

  void clearHistory() {
    _sessions.clear();
    notifyListeners();
  }
}
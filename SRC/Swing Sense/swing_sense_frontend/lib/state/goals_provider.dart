import 'package:flutter/foundation.dart';

import '../models/goal.dart';
import '../services/api_client.dart';
import '../services/goal_service.dart';

class GoalsProvider extends ChangeNotifier {
  GoalsProvider() : _service = GoalService(ApiClient.instance);
  final GoalService _service;

  List<Goal> goals = [];
  bool isLoading = false;

  Future<void> load() async {
    isLoading = true;
    notifyListeners();
    try {
      goals = await _service.list();
    } catch (_) {}
    isLoading = false;
    notifyListeners();
  }

  Future<void> createGoal({
    required String type,
    required String title,
    required double targetValue,
    required String unit,
    DateTime? deadline,
  }) async {
    final goal = await _service.create(
      type: type,
      title: title,
      targetValue: targetValue,
      unit: unit,
      deadline: deadline,
    );
    goals = [goal, ...goals];
    notifyListeners();
  }

  Future<void> removeGoal(String id) async {
    await _service.delete(id);
    goals = goals.where((g) => g.id != id).toList();
    notifyListeners();
  }
}

import 'package:flutter/foundation.dart';

import '../models/training_session.dart';
import '../services/api_client.dart';
import '../services/feed_service.dart';

class FeedProvider extends ChangeNotifier {
  FeedProvider() : _service = FeedService(ApiClient.instance);
  final FeedService _service;

  List<TrainingSession> sessions = [];
  bool isLoading = false;
  String? errorMessage;

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      sessions = await _service.feed();
    } catch (e) {
      errorMessage = e.toString().replaceFirst('ApiException: ', '');
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> toggleLike(TrainingSession session) async {
    final index = sessions.indexWhere((s) => s.id == session.id);
    if (index == -1) return;

    final wasLiked = session.likedByMe;
    final updated = TrainingSession(
      id: session.id,
      userId: session.userId,
      trainingId: session.trainingId,
      trainingTitle: session.trainingTitle,
      title: session.title,
      status: session.status,
      startedAt: session.startedAt,
      endedAt: session.endedAt,
      durationSeconds: session.durationSeconds,
      shotCount: session.shotCount,
      aceCount: session.aceCount,
      avgBallSpeedKmh: session.avgBallSpeedKmh,
      maxBallSpeedKmh: session.maxBallSpeedKmh,
      calories: session.calories,
      notes: session.notes,
      userName: session.userName,
      userAvatarUrl: session.userAvatarUrl,
      likeCount: wasLiked ? session.likeCount - 1 : session.likeCount + 1,
      commentCount: session.commentCount,
      likedByMe: !wasLiked,
    );
    sessions[index] = updated;
    notifyListeners();

    try {
      if (wasLiked) {
        await _service.unlike(session.id);
      } else {
        await _service.like(session.id);
      }
    } catch (_) {
      sessions[index] = session;
      notifyListeners();
    }
  }
}

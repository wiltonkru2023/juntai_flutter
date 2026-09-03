import '../../../core/services/api_service.dart';

class ActivityParticipationException implements Exception {
  const ActivityParticipationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ActivityParticipationService {
  ActivityParticipationService({ApiService? api})
      : _api = api ?? ApiService.instance;

  final ApiService _api;

  Future<void> joinPublic(String activityId) async {
    await _call(() => _api.joinActivity(activityId));
  }

  Future<void> leave(String activityId) async {
    await _call(() => _api.leaveActivity(activityId));
  }

  Future<void> requestPrivate(String activityId) async {
    await _call(() => _api.requestJoinActivity(activityId));
  }

  Future<void> respondRequest({
    required String activityId,
    required String userId,
    required bool accept,
  }) async {
    await _call(
      () => _api.respondJoinRequest(
        activityId: activityId,
        userId: userId,
        accept: accept,
      ),
    );
  }

  Future<void> _call(
    Future<Map<String, dynamic>> Function() action,
  ) async {
    try {
      await action();
    } on ApiException catch (error) {
      throw ActivityParticipationException(error.message);
    } catch (_) {
      throw const ActivityParticipationException(
        'Não foi possível concluir a ação. Tente novamente.',
      );
    }
  }
}

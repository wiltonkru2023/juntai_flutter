import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException({required this.message, this.code, this.statusCode});
  final String message;
  final String? code;
  final int? statusCode;
  @override
  String toString() => message;
}

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();
  static const String baseUrl = 'https://juntai-flutter.onrender.com';

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic> body = const <String, dynamic>{},
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const ApiException(
          message: 'Faça login para continuar.', code: 'unauthenticated');
    }

    final token = await user.getIdToken(true);
    if (token == null || token.isEmpty) {
      throw const ApiException(
          message: 'Não foi possível autenticar sua sessão.');
    }

    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$baseUrl$path'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const ApiException(message: 'O servidor demorou para responder.');
    } catch (_) {
      throw const ApiException(
          message: 'Não foi possível conectar ao servidor.');
    }

    Map<String, dynamic> data = <String, dynamic>{};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) data = Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        message: data['message']?.toString() ??
            'Não foi possível concluir a operação.',
        code: data['code']?.toString(),
        statusCode: response.statusCode,
      );
    }
    return data;
  }

  Future<Map<String, dynamic>> reserveUsername(String username) =>
      post('/reserve-username', body: {'username': username});
  Future<Map<String, dynamic>> changeUsername(String username) =>
      post('/blueprint/change-username', body: {'username': username});

  Future<Map<String, dynamic>> followUser(String userId,
          {required bool follow}) =>
      post('/blueprint/follow-user',
          body: {'userId': userId, 'follow': follow});

  Future<Map<String, dynamic>> syncSocialCounters() =>
      post('/blueprint/sync-social-counters');

  Future<Map<String, dynamic>> createBusiness(Map<String, dynamic> data) =>
      post('/blueprint/create-business', body: data);
  Future<Map<String, dynamic>> updateBusiness(Map<String, dynamic> data) =>
      post('/blueprint/update-business', body: data);
  Future<Map<String, dynamic>> followBusiness(String businessId,
          {required bool follow}) =>
      post('/blueprint/follow-business',
          body: {'businessId': businessId, 'follow': follow});
  Future<Map<String, dynamic>> updateBusinessFollowPreferences(
    String businessId, {
    required bool posts,
    required bool events,
    required bool openSlots,
    required bool benefits,
  }) =>
      post('/blueprint/business-follow-preferences', body: {
        'businessId': businessId,
        'notifyPosts': posts,
        'notifyEvents': events,
        'notifyOpenSlots': openSlots,
        'notifyBenefits': benefits,
      });

  Future<Map<String, dynamic>> createBusinessPost(Map<String, dynamic> data) =>
      post('/blueprint/create-post', body: data);
  Future<Map<String, dynamic>> updateBusinessPost(
          String postId, Map<String, dynamic> data) =>
      post('/blueprint/update-post', body: {'postId': postId, ...data});
  Future<Map<String, dynamic>> archiveBusinessPost(String postId) =>
      post('/blueprint/archive-post', body: {'postId': postId});
  Future<Map<String, dynamic>> trackBusinessPost(String postId, String event) =>
      post('/blueprint/business-metric',
          body: {'postId': postId, 'event': event});
  Future<Map<String, dynamic>> trackBusinessProfile(String businessId) =>
      post('/blueprint/business-profile-visit',
          body: {'businessId': businessId});

  Future<Map<String, dynamic>> setInterested(String postId,
          {required bool interested}) =>
      post('/blueprint/set-interested',
          body: {'postId': postId, 'interested': interested});
  Future<Map<String, dynamic>> claimOpenSlot(String postId,
          {String? slotLabel}) =>
      post('/blueprint/claim-open-slot', body: {
        'postId': postId,
        if (slotLabel != null) 'slotLabel': slotLabel,
      });
  Future<Map<String, dynamic>> benefitStatus(String code) =>
      post('/blueprint/benefit-status', body: {'code': code});
  Future<Map<String, dynamic>> redeemBenefit(String code) =>
      post('/blueprint/redeem-benefit', body: {'code': code});

  Future<Map<String, dynamic>> businessDashboard() =>
      post('/blueprint/business-dashboard');
  Future<Map<String, dynamic>> checkoutPlan(String plan) =>
      post('/blueprint/checkout-plan', body: {'plan': plan});
  Future<Map<String, dynamic>> sponsorPost({
    required String postId,
    required String package,
    String city = '',
  }) =>
      post('/blueprint/sponsor-post', body: {
        'postId': postId,
        'package': package,
        'city': city,
      });

  Future<Map<String, dynamic>> registerDiscoveryActivity({
    required String discoveryId,
    required String activityId,
  }) =>
      post('/blueprint/register-discovery-activity', body: {
        'discoveryId': discoveryId,
        'activityId': activityId,
      });

  Future<Map<String, dynamic>> recordDiscoveryParticipant({
    required String activityId,
    String? userId,
  }) =>
      post('/blueprint/record-discovery-participant', body: {
        'activityId': activityId,
        if (userId != null) 'userId': userId,
      });

  Future<Map<String, dynamic>> joinActivity(String activityId) async {
    final result =
        await post('/join-activity', body: {'activityId': activityId});
    if (result['joined'] == true) {
      try {
        await recordDiscoveryParticipant(activityId: activityId);
      } catch (_) {}
    }
    return result;
  }

  Future<Map<String, dynamic>> leaveActivity(String activityId) =>
      post('/leave-activity', body: {'activityId': activityId});
  Future<Map<String, dynamic>> requestJoinActivity(String activityId) =>
      post('/request-join-activity', body: {'activityId': activityId});

  Future<Map<String, dynamic>> respondJoinRequest({
    required String activityId,
    required String userId,
    required bool accept,
  }) async {
    final result = await post('/respond-join-request', body: {
      'activityId': activityId,
      'userId': userId,
      'accept': accept,
    });
    if (accept) {
      try {
        await recordDiscoveryParticipant(
            activityId: activityId, userId: userId);
      } catch (_) {}
    }
    return result;
  }

  Future<Map<String, dynamic>> reportContent({
    required String targetType,
    required String targetId,
    required String reason,
    String details = '',
  }) =>
      post('/blueprint/report-content', body: {
        'targetType': targetType,
        'targetId': targetId,
        'reason': reason,
        'details': details,
      });

  Future<Map<String, dynamic>> sendPrivateMessage({
    required String otherUserId,
    required Map<String, dynamic> message,
    required String preview,
  }) =>
      post('/send-private-message', body: {
        'otherUserId': otherUserId,
        'message': message,
        'preview': preview,
      });

  Future<Map<String, dynamic>> notifyChatMessage({
    required String activityId,
    required String messageId,
  }) =>
      post('/notify-chat-message',
          body: {'activityId': activityId, 'messageId': messageId});
  Future<Map<String, dynamic>> notifyPrivateMessage({
    required String conversationId,
    required String messageId,
  }) =>
      post('/notify-private-message', body: {
        'conversationId': conversationId,
        'messageId': messageId,
      });

  Future<Map<String, dynamic>> deleteAccount() => post('/delete-account');
  Future<Map<String, dynamic>> cancelActivity(String activityId) =>
      post('/cancel-activity', body: {'activityId': activityId});

  Future<Map<String, dynamic>> updateActivity({
    required String activityId,
    required String title,
    required String description,
    required String category,
    required String address,
    required double latitude,
    required double longitude,
    required String geohash,
    required DateTime startsAt,
    required int maxParticipants,
    required bool isPrivate,
  }) =>
      post('/update-activity', body: {
        'activityId': activityId,
        'title': title,
        'description': description,
        'category': category,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'geohash': geohash,
        'startsAt': startsAt.toUtc().toIso8601String(),
        'maxParticipants': maxParticipants,
        'isPrivate': isPrivate,
      });
}

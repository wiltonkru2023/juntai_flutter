import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.code,
    this.statusCode,
  });

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
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw const ApiException(
        message: 'Faça login para continuar.',
        code: 'unauthenticated',
        statusCode: 401,
      );
    }

    final token = await user.getIdToken();

    if (token == null || token.isEmpty) {
      throw const ApiException(
        message: 'Não foi possível autenticar sua sessão.',
        code: 'unauthenticated',
        statusCode: 401,
      );
    }

    final uri = Uri.parse('$baseUrl$path');
    http.Response response;

    try {
      response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw const ApiException(
        message: 'O servidor demorou para responder. Tente novamente.',
        code: 'timeout',
      );
    } catch (_) {
      throw const ApiException(
        message: 'Não foi possível conectar ao servidor.',
        code: 'network-error',
      );
    }

    Map<String, dynamic> data = <String, dynamic>{};

    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          data = decoded;
        } else if (decoded is Map) {
          data = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        // Resposta sem JSON válido.
      }
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

  Future<Map<String, dynamic>> createBusiness(Map<String, dynamic> data) =>
      post('/create-business', body: data);

  Future<Map<String, dynamic>> updateBusiness(Map<String, dynamic> data) =>
      post('/update-business', body: data);

  Future<Map<String, dynamic>> createBusinessPost(Map<String, dynamic> data) =>
      post('/create-business-post-v2', body: data);

  Future<Map<String, dynamic>> updateBusinessPost(
    String postId,
    Map<String, dynamic> data,
  ) =>
      post('/update-business-post', body: {'postId': postId, ...data});

  Future<Map<String, dynamic>> archiveBusinessPost(String postId) =>
      post('/archive-business-post', body: {'postId': postId});

  Future<Map<String, dynamic>> trackBusinessPost(
    String postId,
    String event,
  ) =>
      post('/business-post-view', body: {'postId': postId, 'event': event});

  Future<Map<String, dynamic>> registerDiscoveryActivity({
    required String discoveryId,
    required String activityId,
  }) =>
      post(
        '/register-discovery-activity',
        body: {
          'discoveryId': discoveryId,
          'activityId': activityId,
        },
      );

  Future<Map<String, dynamic>> joinActivity(String activityId) async {
    final result =
        await post('/join-activity', body: {'activityId': activityId});
    if (result['joined'] == true) {
      try {
        await post(
          '/record-discovery-participant',
          body: {'activityId': activityId},
        );
      } catch (_) {
        // A participação já foi concluída; métrica não deve desfazer a entrada.
      }
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
    final result = await post(
      '/respond-join-request',
      body: {
        'activityId': activityId,
        'userId': userId,
        'accept': accept,
      },
    );

    if (accept) {
      try {
        await post(
          '/record-discovery-participant',
          body: {
            'activityId': activityId,
            'userId': userId,
          },
        );
      } catch (_) {
        // A solicitação já foi aceita; métrica não deve quebrar a ação.
      }
    }
    return result;
  }

  Future<Map<String, dynamic>> reportContent({
    required String targetType,
    required String targetId,
    required String reason,
    String details = '',
  }) =>
      post(
        '/report-content',
        body: {
          'targetType': targetType,
          'targetId': targetId,
          'reason': reason,
          'details': details,
        },
      );

  Future<Map<String, dynamic>> deleteAccount() => post('/delete-account');

  Future<Map<String, dynamic>> notifyChatMessage({
    required String activityId,
    required String messageId,
  }) =>
      post(
        '/notify-chat-message',
        body: {
          'activityId': activityId,
          'messageId': messageId,
        },
      );

  Future<Map<String, dynamic>> sendPrivateMessage({
    required String otherUserId,
    required Map<String, dynamic> message,
    required String preview,
  }) =>
      post(
        '/send-private-message',
        body: {
          'otherUserId': otherUserId,
          'message': message,
          'preview': preview,
        },
      );

  Future<Map<String, dynamic>> notifyPrivateMessage({
    required String conversationId,
    required String messageId,
  }) =>
      post(
        '/notify-private-message',
        body: {
          'conversationId': conversationId,
          'messageId': messageId,
        },
      );

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
      post(
        '/update-activity',
        body: {
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
        },
      );
}

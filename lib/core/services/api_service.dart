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

    final uri = Uri.parse(
      '$baseUrl$path',
    );

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
            body: jsonEncode(
              body,
            ),
          )
          .timeout(
            const Duration(
              seconds: 60,
            ),
          );
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
        final decoded = jsonDecode(
          response.body,
        );

        if (decoded is Map<String, dynamic>) {
          data = decoded;
        } else if (decoded is Map) {
          data = Map<String, dynamic>.from(
            decoded,
          );
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

  Future<Map<String, dynamic>> joinActivity(
    String activityId,
  ) {
    return post(
      '/join-activity',
      body: {
        'activityId': activityId,
      },
    );
  }

  Future<Map<String, dynamic>> createBusiness(Map<String, dynamic> data) =>
      post('/create-business', body: data);

  Future<Map<String, dynamic>> reserveUsername(String username) =>
      post('/reserve-username', body: {'username': username});

  Future<Map<String, dynamic>> createBusinessPost(Map<String, dynamic> data) =>
      post('/create-business-post', body: data);

  Future<Map<String, dynamic>> trackBusinessPost(String postId, String event) =>
      post('/business-post-view', body: {'postId': postId, 'event': event});

  Future<Map<String, dynamic>> leaveActivity(
    String activityId,
  ) {
    return post(
      '/leave-activity',
      body: {
        'activityId': activityId,
      },
    );
  }

  Future<Map<String, dynamic>> requestJoinActivity(
    String activityId,
  ) {
    return post(
      '/request-join-activity',
      body: {
        'activityId': activityId,
      },
    );
  }

  Future<Map<String, dynamic>> respondJoinRequest({
    required String activityId,
    required String userId,
    required bool accept,
  }) {
    return post(
      '/respond-join-request',
      body: {
        'activityId': activityId,
        'userId': userId,
        'accept': accept,
      },
    );
  }

  Future<Map<String, dynamic>> reportContent({
    required String targetType,
    required String targetId,
    required String reason,
    String details = '',
  }) {
    return post(
      '/report-content',
      body: {
        'targetType': targetType,
        'targetId': targetId,
        'reason': reason,
        'details': details,
      },
    );
  }

  Future<Map<String, dynamic>> deleteAccount() {
    return post(
      '/delete-account',
    );
  }

  Future<Map<String, dynamic>> notifyChatMessage({
    required String activityId,
    required String messageId,
  }) {
    return post(
      '/notify-chat-message',
      body: {
        'activityId': activityId,
        'messageId': messageId,
      },
    );
  }

  Future<Map<String, dynamic>> cancelActivity(
    String activityId,
  ) {
    return post(
      '/cancel-activity',
      body: {
        'activityId': activityId,
      },
    );
  }

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
  }) {
    return post(
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
}

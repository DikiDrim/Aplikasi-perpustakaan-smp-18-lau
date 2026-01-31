import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart' as auth;

// Dart FCM relay supporting HTTP v1 (service account) and legacy server key fallback.
// Preferred: set `GOOGLE_SERVICE_ACCOUNT` env to the service account JSON string
// or set `GOOGLE_APPLICATION_CREDENTIALS` to a file path containing the JSON.
// If not present, legacy `FCM_SERVER_KEY` env is used.

Future<Map<String, dynamic>> _parseRequestBody(Request req) async {
  final body = await req.readAsString();
  if (body.isEmpty) return {};
  return json.decode(body) as Map<String, dynamic>;
}

Future<Response> _sendFcm(Request req) async {
  try {
    final data = await _parseRequestBody(req);

    final tokens = (data['tokens'] as List?)?.cast<String>() ?? [];
    final notification =
        (data['notification'] as Map?)?.cast<String, dynamic>() ?? {};
    final payloadData = (data['data'] as Map?)?.cast<String, dynamic>() ?? {};

    if (tokens.isEmpty) {
      return Response(400, body: json.encode({'error': 'tokens required'}));
    }

    // Try HTTP v1 using service account
    final saJsonStr = Platform.environment['GOOGLE_SERVICE_ACCOUNT'];
    final saFilePath = Platform.environment['GOOGLE_APPLICATION_CREDENTIALS'];

    Map<String, dynamic>? saMap;
    if (saJsonStr != null && saJsonStr.isNotEmpty) {
      saMap = json.decode(saJsonStr) as Map<String, dynamic>;
    } else if (saFilePath != null && saFilePath.isNotEmpty) {
      final f = File(saFilePath);
      if (await f.exists()) {
        saMap = json.decode(await f.readAsString()) as Map<String, dynamic>;
      }
    }

    if (saMap != null) {
      final projectId = saMap['project_id'] as String? ??
          Platform.environment['FCM_PROJECT_ID'];
      if (projectId == null) {
        return Response(500,
            body: json.encode({
              'error':
                  'project_id not found in service account or FCM_PROJECT_ID not set'
            }));
      }

      final accountCredentials = auth.ServiceAccountCredentials.fromJson(saMap);
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
      final client =
          await auth.clientViaServiceAccount(accountCredentials, scopes);
      try {
        final url = Uri.parse(
            'https://fcm.googleapis.com/v1/projects/$projectId/messages:send');
        final results = <Map<String, dynamic>>[];
        for (final token in tokens) {
          final message = {
            'message': {
              'token': token,
              if (notification.isNotEmpty) 'notification': notification,
              if (payloadData.isNotEmpty) 'data': payloadData,
            }
          };

          final res = await client.post(url,
              headers: {'Content-Type': 'application/json'},
              body: json.encode(message));
          results.add(
              {'token': token, 'status': res.statusCode, 'body': res.body});
        }
        return Response(200,
            body: json.encode({'results': results}),
            headers: {'content-type': 'application/json'});
      } finally {
        client.close();
      }
    }

    // Fallback: legacy HTTP endpoint using server key (FCM_SERVER_KEY)
    final serverKey = Platform.environment['FCM_SERVER_KEY'];
    if (serverKey == null || serverKey.isEmpty) {
      return Response(500,
          body: json.encode({
            'error':
                'No credentials set for FCM: set GOOGLE_SERVICE_ACCOUNT or FCM_SERVER_KEY'
          }));
    }

    final url = Uri.parse('https://fcm.googleapis.com/fcm/send');
    final legacyPayload = {
      'registration_ids': tokens,
      if (notification.isNotEmpty) 'notification': notification,
      if (payloadData.isNotEmpty) 'data': payloadData,
    };

    final res = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'key=$serverKey',
      },
      body: json.encode(legacyPayload),
    );

    return Response(res.statusCode,
        body: res.body, headers: {'content-type': 'application/json'});
  } catch (e) {
    return Response.internalServerError(
        body: json.encode({'error': e.toString()}));
  }
}

void main(List<String> args) async {
  final router = Router();
  router.post('/send-fcm', _sendFcm);

  final handler =
      const Pipeline().addMiddleware(logRequests()).addHandler(router);

  final portStr = Platform.environment['PORT'] ?? '8080';
  final port = int.tryParse(portStr) ?? 8080;

  final server = await io.serve(handler, InternetAddress.anyIPv4, port);
  print('Dart FCM relay listening on port ${server.port}');
}

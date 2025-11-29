// lib/services/expenses_api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int? statusCode;
  final dynamic body;
  ApiException(this.statusCode, this.body);
  String toString() => 'ApiException(statusCode: $statusCode, body: $body)';
}

class ExpensesApiService {
  ExpensesApiService({required this.apiBase, this.timeoutSeconds = 15});

  final String
  apiBase; // e.g. "https://<api-id>.execute-api.ap-south-1.amazonaws.com"
  final int timeoutSeconds;

  // Defensive id token fetch — returns raw JWT string
  Future<String> _getIdToken() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();
      if (session is CognitoAuthSession) {
        dynamic idTokenObj;
        try {
          // try a few shapes to be robust across Amplify versions
          idTokenObj =
              (session as dynamic).userPoolTokensResult?.value?.idToken?.raw ??
              (session as dynamic).userPoolTokensResult?.value?.idToken ??
              (session as dynamic).userPoolTokens?.idToken ??
              (session as dynamic).userPoolTokens;
        } catch (_) {
          // fallback
          idTokenObj =
              (session as dynamic).userPoolTokens?.idToken ??
              session.userPoolTokens?.idToken;
        }

        if (idTokenObj == null) {
          throw ApiException(401, {
            "error": "No id token available (not signed in)",
          });
        }
        if (idTokenObj is String) {
          final token = idTokenObj.trim();
          safePrint("token:$token");
          if (token.split('.').length == 3) return token;
        }
        // try stringifying and validating
        final candidate = idTokenObj.toString().trim();
        if (candidate.split('.').length == 3) return candidate;
        throw ApiException(401, {
          "error": "idToken not a JWT string",
          "value": candidate,
        });
      }
      throw ApiException(401, {"error": "Not a CognitoAuthSession"});
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(401, {
        "error": "Failed to fetch id token",
        "detail": e.toString(),
      });
    }
  }

  Future<Map<String, String>> _authHeaders() async {
    final idToken = await _getIdToken();
    return {
      HttpHeaders.contentTypeHeader: 'application/json',
      HttpHeaders.authorizationHeader: 'Bearer $idToken',
    };
  }

  Future<Map<String, dynamic>> _handleResponse(http.Response resp) async {
    final status = resp.statusCode;
    if (status >= 200 && status < 300) {
      if (resp.body.trim().isEmpty) return {};
      try {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map &&
            decoded.containsKey('statusCode') &&
            decoded.containsKey('body')) {
          final inner = decoded['body'];
          if (inner is String) return jsonDecode(inner);
          if (inner is Map) return Map<String, dynamic>.from(inner);
        }
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
        return {"data": decoded};
      } catch (e) {
        return {"raw": resp.body};
      }
    } else if (status == 401 || status == 403) {
      throw ApiException(status, resp.body);
    } else {
      dynamic body;
      try {
        body = jsonDecode(resp.body);
      } catch (e) {
        body = resp.body;
      }
      throw ApiException(status, body);
    }
  }

  Future<Map<String, dynamic>> _get(
    String path, [
    Map<String, String>? qs,
  ]) async {
    final uri = Uri.parse('$apiBase$path').replace(queryParameters: qs);
    final headers = await _authHeaders();
    final resp = await http
        .get(uri, headers: headers)
        .timeout(Duration(seconds: timeoutSeconds));
    return _handleResponse(resp);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$apiBase$path');
    final headers = await _authHeaders();
    final resp = await http
        .post(uri, headers: headers, body: jsonEncode(body))
        .timeout(Duration(seconds: timeoutSeconds));
    return _handleResponse(resp);
  }

  Future<Map<String, dynamic>> _put(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$apiBase$path');
    final headers = await _authHeaders();
    final resp = await http
        .put(uri, headers: headers, body: jsonEncode(body))
        .timeout(Duration(seconds: timeoutSeconds));
    return _handleResponse(resp);
  }

  Future<Map<String, dynamic>> _delete(String path) async {
    final uri = Uri.parse('$apiBase$path');
    final headers = await _authHeaders();
    final resp = await http
        .delete(uri, headers: headers)
        .timeout(Duration(seconds: timeoutSeconds));
    return _handleResponse(resp);
  }

  // Public API methods
  Future<Map<String, dynamic>> createExpense({
    required double amount,
    required String category,
    String? date,
    String? timestamp,
    String currency = 'INR',
    String? description,
    String? account,
    String direction = 'expense',
    List<String>? tags,
  }) async {
    final body = <String, dynamic>{
      'amount': amount,
      'category': category,
      if (date != null) 'date': date,
      if (timestamp != null) 'timestamp': timestamp,
      'currency': currency,
      if (description != null) 'description': description,
      if (account != null) 'account': account,
      'direction': direction,
      if (tags != null) 'tags': tags,
    };
    final resp = await _post('/expenses', body);
    return resp;
  }

  Future<Map<String, dynamic>> listExpenses({
    String? startDate,
    String? endDate,
    String? category,
    int limit = 50,
    String? nextToken,
  }) async {
    final qs = <String, String>{};
    if (startDate != null) qs['startDate'] = startDate;
    if (endDate != null) qs['endDate'] = endDate;
    if (category != null) qs['category'] = category;
    qs['limit'] = limit.toString();
    if (nextToken != null) qs['nextToken'] = nextToken;
    final resp = await _get('/expenses', qs);
    return resp;
  }

  Future<Map<String, dynamic>> getExpenseById(String expenseId) async {
    final resp = await _get('/expenses/$expenseId');
    return resp;
  }

  Future<Map<String, dynamic>> updateExpense(
    String expenseId,
    Map<String, dynamic> updates,
  ) async {
    final resp = await _put('/expenses/$expenseId', updates);
    return resp;
  }

  Future<void> deleteExpense(String expenseId) async {
    await _delete('/expenses/$expenseId');
  }

  /// Analysis endpoint: GET /analysis?period=week|month|year
  Future<Map<String, dynamic>> getAnalysis({required String period}) async {
    final qs = {'period': period};
    final resp = await _get('/analysis', qs);
    return resp;
  }
}

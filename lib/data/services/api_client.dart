import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;

class ApiClient {
  final String baseUrl;
  final http.Client _httpClient;

  ApiClient({
    // this.baseUrl = 'http://localhost:3000/api',
    this.baseUrl = 'https://iothomeconnectapiv2-production.up.railway.app/api',

    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// Generic method to make API calls with logging
  Future<Map<String, dynamic>> _request({
    required String method,
    required String endpoint,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final url = Uri.parse('$baseUrl$endpoint');
    http.Response response;

    // Create default headers
    final requestHeaders = {
      'Content-Type': 'application/json',
      ...?headers,
    };

    try {
      // Log request details
      developer.log('API Request: $method $url', name: 'ApiClient');
      if (body != null) {
        developer.log('Request body: ${jsonEncode(body)}', name: 'ApiClient');
      }

      // Make the appropriate request based on the method
      switch (method.toUpperCase()) {
        case 'GET':
          response = await _httpClient.get(url, headers: requestHeaders);
          break;
        case 'POST':
          response = await _httpClient.post(
            url,
            headers: requestHeaders,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case 'PATCH':
          response = await _httpClient.patch(
            url,
            headers: requestHeaders,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case 'PUT':
          response = await _httpClient.put(
            url,
            headers: requestHeaders,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case 'DELETE':
          response = await _httpClient.delete(url, headers: requestHeaders);
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      // Log response details
      developer.log(
        'API Response [${response.statusCode}]: ${response.body}',
        name: 'ApiClient',
      );

      // Parse and return the response
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) {
          return {'success': true};
        }
        return jsonDecode(response.body);
      } else {
        developer.log(
          'API Error [${response.statusCode}]: ${response.body}',
          name: 'ApiClient',
          error: response.body,
        );

        Map<String, dynamic> errorResponse;
        try {
          errorResponse = jsonDecode(response.body);
        } catch (e) {
          errorResponse = {
            'success': false,
            'errorCode': response.statusCode.toString(),
            'message': response.body,
          };
        }

        return errorResponse;
      }
    } catch (e, stackTrace) {
      developer.log(
        'API Exception: $e',
        name: 'ApiClient',
        error: e,
        stackTrace: stackTrace,
      );

      return {
        'success': false,
        'errorCode': 'network_error',
        'message': e.toString(),
      };
    }
  }

  // Convenience methods for different HTTP verbs
  Future<Map<String, dynamic>> get(String endpoint, {Map<String, String>? headers}) async {
    return _request(method: 'GET', endpoint: endpoint, headers: headers);
  }

  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    return _request(method: 'POST', endpoint: endpoint, body: body, headers: headers);
  }

  Future<Map<String, dynamic>> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    return _request(method: 'PATCH', endpoint: endpoint, body: body, headers: headers);
  }

  Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    return _request(method: 'PUT', endpoint: endpoint, body: body, headers: headers);
  }

  Future<Map<String, dynamic>> delete(
    String endpoint, {
    Map<String, String>? headers,
  }) async {
    return _request(method: 'DELETE', endpoint: endpoint, headers: headers);
  }

  // Close the HTTP client when done
  void dispose() {
    _httpClient.close();
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import '../models/migration_model.dart';
import '../../core/constants/api_constants.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  void _checkResponse(Response response) {
    if (response.statusCode >= 400) {
      final body = jsonDecode(response.body);
      throw ApiException(
        body['detail'] ?? 'Server error',
        statusCode: response.statusCode,
      );
    }
  }

  // ── Migrations ─────────────────────────────────────────────────────────────

  Future<MigrationModel> createMigration({
    required String title,
    required String originalCode,
    String? flutterVersionFrom,
    String? flutterVersionTo,
    Map<String, String>? headers,
  }) async {
    final response = await _client.post(
      Uri.parse(ApiConstants.migrations),
      headers: {..._headers, ...?headers},
      body: jsonEncode({
        'title': title,
        'original_code': originalCode,
        if (flutterVersionFrom != null) 'flutter_version_from': flutterVersionFrom,
        if (flutterVersionTo != null) 'flutter_version_to': flutterVersionTo,
      }),
    );
    _checkResponse(response);
    return MigrationModel.fromJson(jsonDecode(response.body));
  }

  Future<List<MigrationModel>> listMigrations({int skip = 0, int limit = 50, Map<String, String>? headers}) async {
    final uri = Uri.parse(ApiConstants.migrations)
        .replace(queryParameters: {'skip': '$skip', 'limit': '$limit'});
    final response = await _client.get(uri, headers: {..._headers, ...?headers});
    _checkResponse(response);
    final data = jsonDecode(response.body);
    return (data['migrations'] as List)
        .map((e) => MigrationModel.fromJson(e))
        .toList();
  }

  Future<MigrationModel> getMigration(int id, {Map<String, String>? headers}) async {
    final response = await _client.get(
      Uri.parse(ApiConstants.migrationById(id)),
      headers: {..._headers, ...?headers},
    );
    _checkResponse(response);
    return MigrationModel.fromJson(jsonDecode(response.body));
  }

  Future<void> deleteMigration(int id, {Map<String, String>? headers}) async {
    final response = await _client.delete(
      Uri.parse(ApiConstants.migrationById(id)),
      headers: {..._headers, ...?headers},
    );
    if (response.statusCode != 204) {
      _checkResponse(response);
    }
  }

  Future<MigrationModel> uploadDartFile({
    required List<int> fileBytes,
    required String fileName,
    String? flutterVersionFrom,
    String? flutterVersionTo,
    Map<String, String>? headers,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(ApiConstants.uploadDart),
    );
    if (headers != null) request.headers.addAll(headers);
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: fileName,
    ));
    if (flutterVersionFrom != null) {
      request.fields['flutter_version_from'] = flutterVersionFrom;
    }
    if (flutterVersionTo != null) {
      request.fields['flutter_version_to'] = flutterVersionTo;
    }
    request.fields['title'] = fileName;

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    _checkResponse(response);
    return MigrationModel.fromJson(jsonDecode(response.body));
  }
  // NEW — Upload ZIP project
  Future<MigrationModel> uploadZipProject({
    required List<int> fileBytes,
    required String fileName,
    String? flutterVersionFrom,
    String? flutterVersionTo,
    Map<String, String>? headers,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(ApiConstants.uploadZip),
    );
    if (headers != null) request.headers.addAll(headers);
    request.files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: fileName));
    if (flutterVersionFrom != null) {
      request.fields['flutter_version_from'] = flutterVersionFrom;
    }
    if (flutterVersionTo != null) {
      request.fields['flutter_version_to'] = flutterVersionTo;
    }
    request.fields['title'] = fileName.replaceAll('.zip', '');

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    _checkResponse(response);
    return MigrationModel.fromJson(jsonDecode(response.body));
  }

  // NEW — Migrate GitHub repo by URL
  Future<MigrationModel> migrateGithubRepo({
    required String githubUrl,
    String? title,
    String? flutterVersionFrom,
    String? flutterVersionTo,
    Map<String, String>? headers,
  }) async {
    final response = await _client.post(
      Uri.parse(ApiConstants.migrateGithub),
      headers: {..._headers, ...?headers},
      body: jsonEncode({
        'github_url': githubUrl,
        if (title != null) 'title': title,
        if (flutterVersionFrom != null) 'flutter_version_from': flutterVersionFrom,
        if (flutterVersionTo != null) 'flutter_version_to': flutterVersionTo,
      }),
    );
    _checkResponse(response);
    return MigrationModel.fromJson(jsonDecode(response.body));
  }

  // NEW — Migrate a single file within a project
  Future<MigrationModel> migrateFileOnDemand({
    required int migrationId,
    required String filePath,
    Map<String, String>? headers,
  }) async {
    final response = await _client.post(
      Uri.parse('${ApiConstants.migrations}/$migrationId/migrate-file'),
      headers: {..._headers, ...?headers},
      body: jsonEncode({'file_path': filePath}),
    );
    _checkResponse(response);
    return MigrationModel.fromJson(jsonDecode(response.body));
  }

  Future<bool> validateKey(String key, String provider) async {
    try {
      final response = await _client.post(
        Uri.parse('${ApiConstants.migrations}/validate-key'),
        headers: _headers,
        body: jsonEncode({'key': key, 'provider': provider}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
import 'package:flutter/material.dart';
import '../data/models/migration_model.dart';
import '../data/services/api_service.dart';

enum MigrationState { idle, loading, success, error }

class MigrationProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  MigrationState _state = MigrationState.idle;
  List<MigrationModel> _migrations = [];
  MigrationModel? _currentMigration;
  String? _errorMessage;

  MigrationState get state => _state;
  List<MigrationModel> get migrations => _migrations;
  MigrationModel? get currentMigration => _currentMigration;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == MigrationState.loading;

  void _setState(MigrationState state, {String? error}) {
    _state = state;
    _errorMessage = error;
    notifyListeners();
  }

  // ── Migrate code ───────────────────────────────────────────────────────────

  Future<MigrationModel?> migrate({
    required String title,
    required String code,
    String? fromVersion,
    String? toVersion,
  }) async {
    _setState(MigrationState.loading);
    try {
      final result = await _api.createMigration(
        title: title,
        originalCode: code,
        flutterVersionFrom: fromVersion,
        flutterVersionTo: toVersion,
      );
      _currentMigration = result;
      _setState(MigrationState.success);
      return result;
    } on ApiException catch (e) {
      _setState(MigrationState.error, error: e.message);
      return null;
    } catch (e) {
      _setState(MigrationState.error, error: e.toString());
      return null;
    }
  }

  Future<MigrationModel?> migrateFile({
    required List<int> fileBytes,
    required String fileName,
    String? fromVersion,
    String? toVersion,
  }) async {
    _setState(MigrationState.loading);
    try {
      final result = await _api.uploadDartFile(
        fileBytes: fileBytes,
        fileName: fileName,
        flutterVersionFrom: fromVersion,
        flutterVersionTo: toVersion,
      );
      _currentMigration = result;
      _setState(MigrationState.success);
      return result;
    } on ApiException catch (e) {
      _setState(MigrationState.error, error: e.message);
      return null;
    } catch (e) {
      _setState(MigrationState.error, error: e.toString());
      return null;
    }
  }

  Future<MigrationModel?> migrateZip({
    required List<int> fileBytes,
    required String fileName,
    String? fromVersion,
    String? toVersion,
  }) async {
    _setState(MigrationState.loading);
    try {
      final result = await _api.uploadZipProject(
        fileBytes: fileBytes,
        fileName: fileName,
        flutterVersionFrom: fromVersion,
        flutterVersionTo: toVersion,
      );
      _currentMigration = result;
      _setState(MigrationState.success);
      return result;
    } on ApiException catch (e) {
      _setState(MigrationState.error, error: e.message);
      return null;
    } catch (e) {
      _setState(MigrationState.error, error: e.toString());
      return null;
    }
  }

  Future<MigrationModel?> migrateGithub({
    required String githubUrl,
    String? title,
    String? fromVersion,
    String? toVersion,
  }) async {
    _setState(MigrationState.loading);
    try {
      final result = await _api.migrateGithubRepo(
        githubUrl: githubUrl,
        title: title,
        flutterVersionFrom: fromVersion,
        flutterVersionTo: toVersion,
      );
      _currentMigration = result;
      _setState(MigrationState.success);
      return result;
    } on ApiException catch (e) {
      _setState(MigrationState.error, error: e.message);
      return null;
    } catch (e) {
      _setState(MigrationState.error, error: e.toString());
      return null;
    }
  }

  Future<void> migrateFileIndividually(int id, String path) async {
    // We don't use global loading here so we can show file-specific loader
    try {
      final result = await _api.migrateFileOnDemand(migrationId: id, filePath: path);
      _currentMigration = result;
      // Update history list if needed
      final idx = _migrations.indexWhere((m) => m.id == id);
      if (idx != -1) _migrations[idx] = result;
      notifyListeners();
    } catch (e) {
      _setState(MigrationState.error, error: e.toString());
    }
  }

  // ── History ────────────────────────────────────────────────────────────────

  Future<void> loadHistory() async {
    _setState(MigrationState.loading);
    try {
      _migrations = await _api.listMigrations();
      _setState(MigrationState.success);
    } catch (e) {
      _setState(MigrationState.error, error: e.toString());
    }
  }

  Future<void> deleteMigration(int id) async {
    try {
      await _api.deleteMigration(id);
      _migrations.removeWhere((m) => m.id == id);
      notifyListeners();
    } catch (e) {
      _setState(MigrationState.error, error: e.toString());
    }
  }

  void setCurrentMigration(MigrationModel migration) {
    _currentMigration = migration;
    notifyListeners();
  }

  void reset() {
    _state = MigrationState.idle;
    _errorMessage = null;
    notifyListeners();
  }
}
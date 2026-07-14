class ApiConstants {
  // ⬇ Change this if your backend runs on a different host/port
  static const String baseUrl = 'http://127.0.0.1:8000';

  // Health
  static const String health = '$baseUrl/health';

  // Migrations
  static const String migrations        = '$baseUrl/api/migrations';
  static const String uploadDart        = '$baseUrl/api/migrations/upload';
  static const String uploadZip         = '$baseUrl/api/migrations/upload-zip';  // NEW
  static const String migrateGithub     = '$baseUrl/api/migrations/github';       // NEW
  static String migrationById(int id)   => '$baseUrl/api/migrations/$id';
}
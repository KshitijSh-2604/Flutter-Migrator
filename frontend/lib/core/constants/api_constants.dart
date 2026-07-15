class ApiConstants {
  // ⬇ Production Backend URL on Render
  static const String baseUrl = 'https://flutter-migrator-backend.onrender.com';

  // Health
  static const String health = '$baseUrl/health';

  // Migrations
  static const String migrations        = '$baseUrl/api/migrations';
  static const String uploadDart        = '$baseUrl/api/migrations/upload';
  static const String uploadZip         = '$baseUrl/api/migrations/upload-zip';  // NEW
  static const String migrateGithub     = '$baseUrl/api/migrations/github';       // NEW
  static String migrationById(int id)   => '$baseUrl/api/migrations/$id';
}
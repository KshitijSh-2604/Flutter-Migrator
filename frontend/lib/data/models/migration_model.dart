import 'dart:convert';

class PackageInfo {
  final String name;
  final String installedVersion;
  final String latestVersion;
  final String status; // ok | upgrade | breaking | unknown

  const PackageInfo({
    required this.name,
    required this.installedVersion,
    required this.latestVersion,
    required this.status,
  });

  factory PackageInfo.fromJson(Map<String, dynamic> j) => PackageInfo(
    name: j['name'] ?? '',
    installedVersion: j['installed_version'] ?? '',
    latestVersion: j['latest_version'] ?? '',
    status: j['status'] ?? 'unknown',
  );

  bool get needsUpgrade => status == 'upgrade' || status == 'breaking';
  bool get isBreaking => status == 'breaking';
}

class MigrationModel {
  final int id;
  final String title;
  final String originalCode;
  final String? migratedCode;
  final String? changesSummary;
  final String? pubspecChanges;
  final String? recommendedPackages;
  final String? migrationSteps;
  final String? flutterVersionFrom;
  final String? flutterVersionTo;
  final String status;
  final String? errorMessage;
  // NEW fields
  final String sourceType;
  final String? githubUrl;
  final String? originalFilename;
  final String? detectedSdk;
  final String? packageAnalysis;
  final String? androidChanges;
  final String? iosChanges;
  final int? confidenceScore;
  final int filesAnalyzed;
  final int filesMigrated;
  final String? filesData;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const MigrationModel({
    required this.id,
    required this.title,
    required this.originalCode,
    this.migratedCode,
    this.changesSummary,
    this.pubspecChanges,
    this.recommendedPackages,
    this.migrationSteps,
    this.flutterVersionFrom,
    this.flutterVersionTo,
    required this.status,
    this.errorMessage,
    this.sourceType = 'paste',
    this.githubUrl,
    this.originalFilename,
    this.detectedSdk,
    this.packageAnalysis,
    this.androidChanges,
    this.iosChanges,
    this.confidenceScore,
    this.filesAnalyzed = 0,
    this.filesMigrated = 0,
    this.filesData,
    required this.createdAt,
    this.updatedAt,
  });

  factory MigrationModel.fromJson(Map<String, dynamic> j) {
    // Ensure the date is treated as UTC even if the 'Z' is missing from the backend
    var rawDate = j['created_at'] as String;
    
    // SQLite might return space instead of T
    rawDate = rawDate.replaceFirst(' ', 'T');
    
    if (!rawDate.endsWith('Z') && !rawDate.contains('+')) {
      rawDate += 'Z';
    }
    
    return MigrationModel(
      id: j['id'],
      title: j['title'],
      originalCode: j['original_code'],
      migratedCode: j['migrated_code'],
      changesSummary: j['changes_summary'],
      pubspecChanges: j['pubspec_changes'],
      recommendedPackages: j['recommended_packages'],
      migrationSteps: j['migration_steps'],
      flutterVersionFrom: j['flutter_version_from'],
      flutterVersionTo: j['flutter_version_to'],
      status: j['status'],
      errorMessage: j['error_message'],
      sourceType: j['source_type'] ?? 'paste',
      githubUrl: j['github_url'],
      originalFilename: j['original_filename'],
      detectedSdk: j['detected_sdk'],
      packageAnalysis: j['package_analysis'],
      androidChanges: j['android_changes'],
      iosChanges: j['ios_changes'],
      confidenceScore: j['confidence_score'],
      filesAnalyzed: j['files_analyzed'] ?? 0,
      filesMigrated: j['files_migrated'] ?? 0,
      filesData: j['files_data'],
      createdAt: DateTime.parse(rawDate).toLocal(),
      updatedAt: j['updated_at'] != null 
          ? DateTime.parse((j['updated_at'] as String).replaceFirst(' ', 'T') + (j['updated_at'].toString().endsWith('Z') ? '' : 'Z')).toLocal() 
          : null,
    );
  }

  // Parsed getters
  Map<String, dynamic> get parsedFilesData {
    if (filesData == null) return {};
    return Map<String, dynamic>.from(jsonDecode(filesData!));
  }
  List<Map<String, dynamic>> get parsedChanges {
    if (changesSummary == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(changesSummary!));
  }

  Map<String, dynamic> get parsedPubspecChanges {
    if (pubspecChanges == null) return {};
    return Map<String, dynamic>.from(jsonDecode(pubspecChanges!));
  }

  List<Map<String, dynamic>> get parsedRecommendedPackages {
    if (recommendedPackages == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(recommendedPackages!));
  }

  List<String> get parsedMigrationSteps {
    if (migrationSteps == null) return [];
    return List<String>.from(jsonDecode(migrationSteps!));
  }

  List<PackageInfo> get parsedPackageAnalysis {
    if (packageAnalysis == null) return [];
    final list = jsonDecode(packageAnalysis!) as List;
    return list.map((e) => PackageInfo.fromJson(e)).toList();
  }

  // Convenience
  bool get isCompleted => status == 'completed';
  bool get isFailed    => status == 'failed';
  bool get isPending   => status == 'pending';

  int get ruleChanges => parsedChanges.where((c) => c['source'] == 'rule_engine').length;
  int get aiChanges   => parsedChanges.where((c) => c['source'] == 'ai').length;
}
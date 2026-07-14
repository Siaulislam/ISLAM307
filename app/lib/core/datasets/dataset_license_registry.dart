import 'dart:convert';

import 'package:flutter/services.dart';

enum DatasetLicenseStatus {
  approvedForBundling,
  appOwned,
  permissionPending,
  reviewRequired,
  sourceNotSelected,
  scholarlyReviewRequired,
  unavailable,
}

class DatasetLicenseRecord {
  const DatasetLicenseRecord({
    required this.id,
    required this.title,
    required this.status,
    required this.originalSource,
    required this.license,
    required this.copyrightOwner,
    required this.contact,
    required this.version,
    required this.downloadDate,
    required this.offlineRedistribution,
    required this.commercialDistribution,
    required this.attribution,
    required this.evidence,
  });

  final String id;
  final String title;
  final DatasetLicenseStatus status;
  final String originalSource;
  final String license;
  final String copyrightOwner;
  final String contact;
  final String version;
  final String? downloadDate;
  final bool offlineRedistribution;
  final bool commercialDistribution;
  final String attribution;
  final String evidence;

  bool get mayBundle =>
      (status == DatasetLicenseStatus.approvedForBundling ||
          status == DatasetLicenseStatus.appOwned) &&
      offlineRedistribution &&
      commercialDistribution;

  factory DatasetLicenseRecord.fromJson(Map<String, dynamic> json) {
    return DatasetLicenseRecord(
      id: '${json['id']}',
      title: '${json['title']}',
      status: _parseStatus('${json['status']}'),
      originalSource: '${json['original_source'] ?? ''}',
      license: '${json['license'] ?? ''}',
      copyrightOwner: '${json['copyright_owner'] ?? ''}',
      contact: '${json['contact'] ?? ''}',
      version: '${json['version'] ?? ''}',
      downloadDate: json['download_date'] as String?,
      offlineRedistribution: json['offline_redistribution'] == true,
      commercialDistribution: json['commercial_distribution'] == true,
      attribution: '${json['attribution'] ?? ''}',
      evidence: '${json['evidence'] ?? ''}',
    );
  }

  static DatasetLicenseStatus _parseStatus(String raw) {
    return switch (raw) {
      'approved_for_bundling' => DatasetLicenseStatus.approvedForBundling,
      'app_owned' => DatasetLicenseStatus.appOwned,
      'permission_pending' => DatasetLicenseStatus.permissionPending,
      'review_required' => DatasetLicenseStatus.reviewRequired,
      'source_not_selected' => DatasetLicenseStatus.sourceNotSelected,
      'scholarly_review_required' =>
        DatasetLicenseStatus.scholarlyReviewRequired,
      _ => DatasetLicenseStatus.unavailable,
    };
  }

  String get statusLabel => switch (status) {
        DatasetLicenseStatus.approvedForBundling => 'Approved for bundling',
        DatasetLicenseStatus.appOwned => 'App-owned / user data',
        DatasetLicenseStatus.permissionPending => 'Permission pending',
        DatasetLicenseStatus.reviewRequired => 'License review required',
        DatasetLicenseStatus.sourceNotSelected => 'Licensed source not selected',
        DatasetLicenseStatus.scholarlyReviewRequired =>
          'Scholarly review required',
        DatasetLicenseStatus.unavailable => 'Unavailable',
      };
}

class LicensedFeatureDefinition {
  const LicensedFeatureDefinition({
    required this.id,
    required this.title,
    required this.route,
    required this.datasetId,
    required this.kind,
  });

  final String id;
  final String title;
  final String route;
  final String datasetId;
  final String kind;

  factory LicensedFeatureDefinition.fromJson(Map<String, dynamic> json) {
    return LicensedFeatureDefinition(
      id: '${json['id']}',
      title: '${json['title']}',
      route: '${json['route']}',
      datasetId: '${json['dataset_id']}',
      kind: '${json['kind']}',
    );
  }
}

class DatasetLicenseRegistry {
  DatasetLicenseRegistry._();
  static final DatasetLicenseRegistry instance = DatasetLicenseRegistry._();

  Future<List<DatasetLicenseRecord>>? _datasetsRequest;
  Future<List<LicensedFeatureDefinition>>? _featuresRequest;

  Future<List<DatasetLicenseRecord>> datasets() {
    return _datasetsRequest ??= _loadDatasets();
  }

  Future<List<LicensedFeatureDefinition>> features() {
    return _featuresRequest ??= _loadFeatures();
  }

  Future<DatasetLicenseRecord?> dataset(String id) async {
    for (final record in await datasets()) {
      if (record.id == id) return record;
    }
    return null;
  }

  Future<LicensedFeatureDefinition?> feature(String id) async {
    for (final definition in await features()) {
      if (definition.id == id) return definition;
    }
    return null;
  }

  Future<bool> mayUseFeature(String featureId) async {
    final definition = await feature(featureId);
    if (definition == null) return false;
    final record = await dataset(definition.datasetId);
    return record?.mayBundle == true;
  }

  Future<List<DatasetLicenseRecord>> _loadDatasets() async {
    final raw =
        await rootBundle.loadString('assets/modules/dataset_registry.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return (decoded['datasets'] as List)
        .map((item) => DatasetLicenseRecord.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();
  }

  Future<List<LicensedFeatureDefinition>> _loadFeatures() async {
    final raw =
        await rootBundle.loadString('assets/modules/feature_modules.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return (decoded['features'] as List)
        .map((item) => LicensedFeatureDefinition.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();
  }
}

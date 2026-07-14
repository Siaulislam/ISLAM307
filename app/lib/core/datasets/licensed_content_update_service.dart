import 'dataset_license_registry.dart';

class ContentUpdateResult {
  const ContentUpdateResult({
    required this.datasetId,
    required this.status,
    required this.message,
  });

  final String datasetId;
  final String status;
  final String message;
}

/// User-triggered update gate. It deliberately performs no background network
/// request and cannot download a permission-pending dataset.
class LicensedContentUpdateService {
  LicensedContentUpdateService._();
  static final LicensedContentUpdateService instance =
      LicensedContentUpdateService._();

  Future<ContentUpdateResult> checkForUpdate(String datasetId) async {
    final record = await DatasetLicenseRegistry.instance.dataset(datasetId);
    if (record == null) {
      return ContentUpdateResult(
        datasetId: datasetId,
        status: 'blocked',
        message: 'Unknown dataset. No network request was made.',
      );
    }
    if (!record.mayBundle) {
      return ContentUpdateResult(
        datasetId: datasetId,
        status: 'permission_pending',
        message:
            '${record.title} cannot be downloaded until offline commercial redistribution is approved.',
      );
    }
    return ContentUpdateResult(
      datasetId: datasetId,
      status: 'no_update_endpoint',
      message:
          '${record.title} is approved, but no signed official update endpoint is configured. Existing content remains unchanged.',
    );
  }
}

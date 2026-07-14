/// Compatibility facade for permission-pending content repositories.
///
/// Religious catalogs remain empty until DatasetLicenseRegistry marks an exact
/// dataset approved for offline commercial bundling.
class ModuleCatalog {
  ModuleCatalog._();
  static final ModuleCatalog instance = ModuleCatalog._();

  Future<List<String>> enabledHadithSlugs() async => const [];

  Future<List<Map<String, dynamic>>> allNarratorSources() async => const [];
}

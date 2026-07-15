class TafsirSourceDefinition {
  const TafsirSourceDefinition({
    required this.slug,
    required this.name,
    required this.nameArabic,
    required this.author,
    required this.preferredLanguage,
    required this.apiAliases,
    required this.licenseNote,
  });

  final String slug;
  final String name;
  final String nameArabic;
  final String author;
  final String preferredLanguage;
  final List<String> apiAliases;
  final String licenseNote;

  bool matchesApiResource(TafsirApiResource resource) {
    final candidates = {
      resource.slug,
      resource.name,
      resource.translatedName,
    }.map(_normalize).where((value) => value.isNotEmpty).toSet();
    return apiAliases.map(_normalize).any(candidates.contains);
  }

  Map<String, dynamic> toCatalogMap({
    TafsirApiResource? resource,
    String? unavailableReason,
    bool retryable = false,
  }) {
    return {
      'slug': slug,
      'name_en': resource?.name ?? name,
      'name_ar': nameArabic,
      'author': resource?.author ?? author,
      'language': resource?.language ?? preferredLanguage,
      'available': resource != null,
      'provider': 'quran_foundation',
      'provider_name': 'Quran Foundation Content API',
      'api_resource_id': resource?.id,
      'api_resource_slug': resource?.slug,
      'notes': resource == null ? unavailableReason ?? licenseNote : licenseNote,
      'retryable': retryable,
    };
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06ff]+'), '');
}

class TafsirApiResource {
  const TafsirApiResource({
    required this.id,
    required this.name,
    required this.author,
    required this.slug,
    required this.language,
    required this.translatedName,
  });

  final int id;
  final String name;
  final String author;
  final String slug;
  final String language;
  final String translatedName;

  factory TafsirApiResource.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final id = rawId is int ? rawId : int.tryParse('$rawId');
    if (id == null || id <= 0) {
      throw const FormatException('Invalid Tafseer resource id');
    }
    final translated = json['translated_name'];
    return TafsirApiResource(
      id: id,
      name: '${json['name'] ?? ''}'.trim(),
      author: '${json['author_name'] ?? ''}'.trim(),
      slug: '${json['slug'] ?? ''}'.trim(),
      language: '${json['language_name'] ?? ''}'.trim(),
      translatedName: translated is Map
          ? '${translated['name'] ?? ''}'.trim()
          : '',
    );
  }
}

class TafsirEntry {
  const TafsirEntry({
    required this.sourceSlug,
    required this.sourceName,
    required this.author,
    required this.provider,
    required this.language,
    required this.surah,
    required this.ayah,
    required this.text,
    required this.citation,
    required this.referenceUrl,
    required this.resourceId,
  });

  final String sourceSlug;
  final String sourceName;
  final String author;
  final String provider;
  final String language;
  final int surah;
  final int ayah;
  final String text;
  final String citation;
  final String referenceUrl;
  final int resourceId;

  Map<String, dynamic> toMap() => {
        'slug': sourceSlug,
        'source_slug': sourceSlug,
        'source_name': sourceName,
        'author': author,
        'source': provider,
        'language': language,
        'surah_number': surah,
        'ayah_number': ayah,
        'text': text,
        'citation': citation,
        'reference_url': referenceUrl,
        'api_resource_id': resourceId,
      };
}

const requestedTafsirSources = <TafsirSourceDefinition>[
  TafsirSourceDefinition(
    slug: 'ibn-kathir',
    name: 'Tafsir Ibn Kathir',
    nameArabic: 'تفسير ابن كثير',
    author: 'Hafiz Ibn Kathir',
    preferredLanguage: 'english',
    apiAliases: [
      'en-tafsir-ibn-kathir',
      'tafsir-ibn-kathir',
      'Tafsir Ibn Kathir',
    ],
    licenseNote:
        'Direct display only under Quran Foundation Developer Terms; no bundled corpus. Ordinary API content is never cached for more than one week.',
  ),
  TafsirSourceDefinition(
    slug: 'al-tabari',
    name: 'Tafsir Al-Tabari',
    nameArabic: 'تفسير الطبري',
    author: 'Imam Al-Tabari',
    preferredLanguage: 'arabic',
    apiAliases: ['tafsir-tabari', 'tafsir-al-tabari', 'Tafsir al-Tabari'],
    licenseNote:
        'Available only when returned by the approved Quran Foundation resource registry. Resource IDs are never hard-coded.',
  ),
  TafsirSourceDefinition(
    slug: 'al-qurtubi',
    name: 'Tafsir Al-Qurtubi',
    nameArabic: 'تفسير القرطبي',
    author: 'Imam Al-Qurtubi',
    preferredLanguage: 'arabic',
    apiAliases: ['tafsir-qurtubi', 'tafsir-al-qurtubi', 'Tafsir Al-Qurtubi'],
    licenseNote:
        'Direct-query only when present in the authenticated Quran Foundation registry; no redistribution.',
  ),
  TafsirSourceDefinition(
    slug: 'al-baghawi',
    name: 'Tafsir Al-Baghawi',
    nameArabic: 'تفسير البغوي',
    author: 'Imam Al-Baghawi',
    preferredLanguage: 'arabic',
    apiAliases: ['tafsir-baghawi', 'tafsir-al-baghawi', 'Tafsir Al-Baghawi'],
    licenseNote:
        'Direct-query only when present in the authenticated Quran Foundation registry; no redistribution.',
  ),
  TafsirSourceDefinition(
    slug: 'al-jalalayn',
    name: 'Tafsir Al-Jalalayn',
    nameArabic: 'تفسير الجلالين',
    author: 'Jalal al-Din al-Mahalli and Jalal al-Din al-Suyuti',
    preferredLanguage: 'arabic',
    apiAliases: ['tafsir-jalalayn', 'tafsir-al-jalalayn', 'Tafsir Al-Jalalayn'],
    licenseNote:
        'Unavailable unless an exact authorized resource is returned by the Quran Foundation API. No licensed public API was otherwise verified.',
  ),
  TafsirSourceDefinition(
    slug: 'as-sadi',
    name: "Tafsir As-Sa'di",
    nameArabic: 'تفسير السعدي',
    author: "Abd al-Rahman al-Sa'di",
    preferredLanguage: 'arabic',
    apiAliases: ['tafsir-sadi', 'tafsir-as-sadi', "Tafsir As-Sa'di", 'Tafsir Al-Saadi'],
    licenseNote:
        'Modern work: direct API display only when authorized by Quran Foundation. No bundled or permanent copy.',
  ),
  TafsirSourceDefinition(
    slug: 'tafhim-ul-quran',
    name: 'Tafhim-ul-Quran',
    nameArabic: 'تفہیم القرآن',
    author: "Syed Abul A'la Maududi",
    preferredLanguage: 'urdu',
    apiAliases: ['tafhim-ul-quran', 'tafheem-ul-quran', 'Tafhim ul Quran'],
    licenseNote:
        'No official licensed API was verified. Unavailable until the publisher or an authorized API grants access.',
  ),
  TafsirSourceDefinition(
    slug: 'maariful-quran',
    name: "Ma'ariful Quran",
    nameArabic: 'معارف القرآن',
    author: 'Mufti Muhammad Shafi',
    preferredLanguage: 'english',
    apiAliases: ['maarif-ul-quran', 'maariful-quran', "Ma'ariful Quran"],
    licenseNote:
        'Modern work: direct API display only if the authenticated Quran Foundation registry authorizes the resource. Never bundled.',
  ),
];

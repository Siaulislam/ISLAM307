import '../tafsir/quran_verse_validator.dart';

class TafsirIntent {
  const TafsirIntent({
    required this.isTafsirRequest,
    this.surah,
    this.ayah,
  });

  final bool isTafsirRequest;
  final int? surah;
  final int? ayah;

  bool get hasVerse => surah != null && ayah != null;

  static TafsirIntent parse(String question) {
    final normalized = question.trim().toLowerCase();
    final match = RegExp(r'\b(\d{1,3})\s*[:/]\s*(\d{1,3})\b')
        .firstMatch(normalized);
    final explicitTafsirWords = [
      'tafsir',
      'tafseer',
      'explain this verse',
      'explain this ayah',
      'explain verse',
      'meaning of this ayah',
      'meaning of this verse',
      'تفسیر',
      'تفسير',
    ].any(normalized.contains);
    final asksForExplanation = match != null &&
        [
          'explain',
          'meaning',
          'interpret',
          'شرح',
          'وضاحت',
        ].any(normalized.contains);
    final asksForTafsir = explicitTafsirWords || asksForExplanation;
    if (!asksForTafsir) {
      return const TafsirIntent(isTafsirRequest: false);
    }

    if (match == null) {
      return const TafsirIntent(isTafsirRequest: true);
    }
    final surah = int.tryParse(match.group(1)!);
    final ayah = int.tryParse(match.group(2)!);
    if (surah == null ||
        ayah == null ||
        !QuranVerseValidator.isValid(surah, ayah)) {
      return const TafsirIntent(isTafsirRequest: true);
    }
    return TafsirIntent(
      isTafsirRequest: true,
      surah: surah,
      ayah: ayah,
    );
  }
}

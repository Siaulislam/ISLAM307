import 'package:flutter/material.dart';

import '../../core/theme/islam307_theme.dart';

class TafsirAttribution extends StatelessWidget {
  const TafsirAttribution({super.key, required this.entry});

  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Tafseer', '${entry['source_name'] ?? '—'}'),
      ('Author', '${entry['author'] ?? '—'}'),
      ('Source', '${entry['source'] ?? '—'}'),
      ('Language', '${entry['language'] ?? '—'}'),
      ('Citation', '${entry['citation'] ?? '—'}'),
      if ('${entry['reference_url'] ?? ''}'.trim().isNotEmpty)
        ('Reference', '${entry['reference_url']}'),
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Islam307Theme.emeraldSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows
            .map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${row.$1}: ${row.$2}',
                  style: const TextStyle(
                    height: 1.35,
                    fontSize: 12,
                    color: Islam307Theme.emeraldDeep,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

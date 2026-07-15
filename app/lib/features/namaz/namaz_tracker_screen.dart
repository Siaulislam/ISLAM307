import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/islam307_theme.dart';

class NamazTrackerScreen extends StatefulWidget {
  const NamazTrackerScreen({super.key});

  @override
  State<NamazTrackerScreen> createState() => _NamazTrackerScreenState();
}

class _NamazTrackerScreenState extends State<NamazTrackerScreen> {
  static const _prayers = [
    ('Fajr', 'فجر'),
    ('Dhuhr', 'ظہر'),
    ('Asr', 'عصر'),
    ('Maghrib', 'مغرب'),
    ('Isha', 'عشاء'),
  ];

  final Map<String, bool> _completed = {};
  bool _loading = true;

  String get _dateKey {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    for (final prayer in _prayers) {
      _completed[prayer.$1] =
          prefs.getBool('namaz_${_dateKey}_${prayer.$1}') ?? false;
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _toggle(String prayer, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('namaz_${_dateKey}_$prayer', value);
    if (!mounted) return;
    setState(() => _completed[prayer] = value);
  }

  int get _done => _completed.values.where((value) => value).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Namaz Tracker',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Islam307Theme.emerald),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Islam307Theme.emeraldSoft,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Islam307Theme.emerald.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _dateKey,
                        style: const TextStyle(
                          color: Islam307Theme.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$_done / ${_prayers.length}',
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: Islam307Theme.emeraldDeep,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _done / _prayers.length,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(99),
                        color: Islam307Theme.emerald,
                        backgroundColor: Colors.white,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                ..._prayers.map(
                  (prayer) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: CheckboxListTile(
                      value: _completed[prayer.$1] ?? false,
                      activeColor: Islam307Theme.emerald,
                      secondary: const Icon(
                        Icons.mosque_rounded,
                        color: Islam307Theme.gold,
                      ),
                      title: Text(
                        prayer.$1,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        prayer.$2,
                        textDirection: TextDirection.rtl,
                        style: Islam307Theme.urdu(size: 17),
                      ),
                      onChanged: (value) =>
                          _toggle(prayer.$1, value ?? false),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This private tracker records completion only. It does not calculate prayer times or replace local mosque guidance.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Islam307Theme.textMuted,
                    height: 1.45,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
    );
  }
}

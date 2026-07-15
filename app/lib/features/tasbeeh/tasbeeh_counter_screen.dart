import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/islam307_theme.dart';

class TasbeehCounterScreen extends StatefulWidget {
  const TasbeehCounterScreen({super.key});

  @override
  State<TasbeehCounterScreen> createState() => _TasbeehCounterScreenState();
}

class _TasbeehCounterScreenState extends State<TasbeehCounterScreen> {
  static const _countKey = 'tasbeeh_count';
  static const _targetKey = 'tasbeeh_target';
  static const _labelKey = 'tasbeeh_label';

  final _labelController = TextEditingController();
  int _count = 0;
  int _target = 33;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _count = prefs.getInt(_countKey) ?? 0;
    _target = prefs.getInt(_targetKey) ?? 33;
    _labelController.text = prefs.getString(_labelKey) ?? 'My Tasbeeh';
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_countKey, _count);
    await prefs.setInt(_targetKey, _target);
    await prefs.setString(_labelKey, _labelController.text.trim());
  }

  Future<void> _increment() async {
    setState(() => _count++);
    await _persist();
    if (_count == _target && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Target $_target completed')),
      );
    }
  }

  Future<void> _decrement() async {
    if (_count == 0) return;
    setState(() => _count--);
    await _persist();
  }

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset counter?'),
        content: const Text('The current Tasbeeh count will return to zero.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _count = 0);
    await _persist();
  }

  Future<void> _setTarget(int target) async {
    setState(() => _target = target);
    await _persist();
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tasbeeh Counter',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        ),
        actions: [
          IconButton(
            tooltip: 'Reset',
            onPressed: _reset,
            icon: const Icon(Icons.restart_alt_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Islam307Theme.emerald),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                TextField(
                  controller: _labelController,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    labelText: 'Tasbeeh name',
                    prefixIcon: Icon(Icons.edit_rounded),
                  ),
                  onSubmitted: (_) => _persist(),
                  onTapOutside: (_) {
                    FocusScope.of(context).unfocus();
                    _persist();
                  },
                ),
                const SizedBox(height: 18),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [33, 99, 100, 500]
                      .map(
                        (target) => ChoiceChip(
                          label: Text('$target'),
                          selected: _target == target,
                          onSelected: (_) => _setTarget(target),
                          selectedColor: Islam307Theme.emerald,
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _target == target ? Colors.white : null,
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 22),
                GestureDetector(
                  onTap: _increment,
                  child: Container(
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [
                          Islam307Theme.emerald,
                          Islam307Theme.emeraldDeep,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              Islam307Theme.emerald.withValues(alpha: 0.28),
                          blurRadius: 28,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$_count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 64,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Target $_target',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'TAP TO COUNT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _decrement,
                        icon: const Icon(Icons.remove_rounded),
                        label: const Text('Minus one'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _reset,
                        icon: const Icon(Icons.restart_alt_rounded),
                        label: const Text('Reset'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Your label and counter are stored locally on this device.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Islam307Theme.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
    );
  }
}

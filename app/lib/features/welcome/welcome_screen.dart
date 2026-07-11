import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/islam307_theme.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  int _lang = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Islam307Theme.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              const Text('Welcome to ISLAM 307', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Islam307Theme.emeraldDeep)),
              const SizedBox(height: 8),
              const Text('Quran · Hadith · Prayer · AI — fully offline', textAlign: TextAlign.center, style: TextStyle(color: Islam307Theme.textMuted)),
              const SizedBox(height: 32),
              const Text('Choose language', style: TextStyle(fontWeight: FontWeight.w700, color: Islam307Theme.textMuted)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _langChip(0, 'العربية'),
                  const SizedBox(width: 8),
                  _langChip(1, 'English'),
                  const SizedBox(width: 8),
                  _langChip(2, 'اردو'),
                ],
              ),
              const Spacer(),
              FilledButton(onPressed: () => context.go('/home'), child: const Text('Get Started')),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.go('/home'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Islam307Theme.emeraldDeep,
                  side: const BorderSide(color: Islam307Theme.emerald, width: 2),
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Continue as Guest', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _langChip(int i, String label) {
    final selected = _lang == i;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _lang = i),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Islam307Theme.emerald : Islam307Theme.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? Islam307Theme.emerald : Islam307Theme.cardBorder),
          ),
          child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: selected ? Colors.white : Islam307Theme.textPrimary, fontSize: 13)),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class MigrationScreen extends StatelessWidget {
  const MigrationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Migration')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.swap_horiz_rounded,
                size: 64,
                color: AppTheme.textSecond.withOpacity(0.4),
              ),
              const SizedBox(height: 14),
              const Text(
                'Migration Assistant',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Source-to-source content migration will be added in a future update.',
                style: TextStyle(color: AppTheme.textSecond, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

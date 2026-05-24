import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Library')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.collections_bookmark_rounded,
              size: 64,
              color: AppTheme.textSecond.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your library is empty',
              style: TextStyle(
                color: AppTheme.textSecond,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add manga or anime to your library\nto track your progress',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecond, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

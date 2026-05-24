import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        children: [
          _buildSection('Sources', [
            _buildTile(
              context,
              icon: Icons.source_rounded,
              title: 'Repositories',
              subtitle: 'Manage extension sources',
              onTap: () => context.push('/more/repositories'),
            ),
            _buildTile(
              context,
              icon: Icons.download_rounded,
              title: 'Downloads',
              subtitle: 'Manage downloaded content',
              onTap: () {},
            ),
          ]),
          _buildSection('Library', [
            _buildTile(
              context,
              icon: Icons.swap_horiz_rounded,
              title: 'Migration',
              subtitle: 'Migrate content between extensions',
              onTap: () => context.push('/more/migration'),
            ),
            _buildTile(
              context,
              icon: Icons.file_upload_rounded,
              title: 'Import Local',
              subtitle: 'Import CBZ, EPUB, MP4 files',
              onTap: () {},
            ),
          ]),
          _buildSection('App', [
            _buildTile(
              context,
              icon: Icons.settings_rounded,
              title: 'Settings',
              subtitle: 'App preferences',
              onTap: () => context.push('/more/settings'),
            ),
            _buildTile(
              context,
              icon: Icons.info_outline_rounded,
              title: 'About',
              subtitle: 'KomiVerse v1.0.0',
              onTap: () {},
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> tiles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppTheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ...tiles,
        const Divider(color: AppTheme.surface, height: 1),
      ],
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppTheme.primary, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppTheme.textSecond, fontSize: 12),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppTheme.textSecond,
      ),
      onTap: onTap,
    );
  }
}

import 'package:flutter/material.dart';
import '../../../core/config/app_settings_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _backendUrlController;
  bool _isSaving = false;
  bool _isLoadingSources = false;
  List<Map<String, dynamic>> _sources = [];

  @override
  void initState() {
    super.initState();
    _backendUrlController = TextEditingController(
      text: ApiClient.currentBaseUrl,
    );
    _loadSources();
  }

  @override
  void dispose() {
    _backendUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveBackendUrl() async {
    final input = _backendUrlController.text.trim();
    if (input.isEmpty) {
      _showMessage('Backend URL cannot be empty.', isError: true);
      return;
    }

    final uri = Uri.tryParse(input);
    if (uri == null || !(uri.hasScheme && uri.host.isNotEmpty)) {
      _showMessage(
        'Enter a valid URL like http://192.168.1.10:8081 or http://127.0.0.1:8081',
        isError: true,
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ApiClient.setBaseUrl(input);
      if (!mounted) {
        return;
      }
      _showMessage('Backend URL updated to ${ApiClient.currentBaseUrl}');
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showMessage(e.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _loadSources() async {
    setState(() => _isLoadingSources = true);
    try {
      final res = await ApiClient.getSources();
      final list =
          (res.data['sources'] as List?)
              ?.map((item) => item as Map<String, dynamic>)
              .toList() ??
          [];
      if (!mounted) {
        return;
      }
      setState(() => _sources = list);
    } catch (_) {
      // Keep settings usable even when sources cannot be fetched.
    } finally {
      if (mounted) {
        setState(() => _isLoadingSources = false);
      }
    }
  }

  void _showMessage(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? Colors.red.shade700 : AppTheme.primary,
        content: Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _buildSectionTitle('Backend'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: _sectionDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Backend URL',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _backendUrlController,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'http://127.0.0.1:8081',
                    hintStyle: const TextStyle(color: AppTheme.textSecond),
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Phone via USB: use http://127.0.0.1:8081 with adb reverse.\nPhone via Wi-Fi: use your PC LAN IP (example: http://192.168.1.50:8081).',
                  style: TextStyle(color: AppTheme.textSecond, fontSize: 11.5),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveBackendUrl,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(_isSaving ? 'Saving...' : 'Save Backend URL'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppTheme.surface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildSectionTitle('Default Sources'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: _sectionDecoration(),
            child: _isLoadingSources
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: CircularProgressIndicator(
                        color: AppTheme.primary,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : Column(
                    children: [
                      _buildSourcePicker(
                        type: 'manga',
                        label: 'Manga Source',
                        accent: AppTheme.primary,
                      ),
                      const SizedBox(height: 10),
                      _buildSourcePicker(
                        type: 'anime',
                        label: 'Anime Source',
                        accent: const Color(0xFF06B6D4),
                      ),
                      const SizedBox(height: 10),
                      _buildSourcePicker(
                        type: 'novel',
                        label: 'Novel Source',
                        accent: const Color(0xFFF59E0B),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 20),
          _buildSectionTitle('Reader'),
          Container(
            decoration: _sectionDecoration(),
            child: ValueListenableBuilder<ReaderDirectionPreference>(
              valueListenable: AppSettingsService.readingDirectionNotifier,
              builder: (context, direction, _) {
                return Column(
                  children: [
                    RadioListTile<ReaderDirectionPreference>(
                      value: ReaderDirectionPreference.ltr,
                      groupValue: direction,
                      activeColor: AppTheme.primary,
                      title: const Text(
                        'Left to Right',
                        style: TextStyle(color: AppTheme.textPrimary),
                      ),
                      subtitle: const Text(
                        'Manga/novel reader starts from left side.',
                        style: TextStyle(
                          color: AppTheme.textSecond,
                          fontSize: 12,
                        ),
                      ),
                      onChanged: (value) {
                        if (value != null) {
                          AppSettingsService.setReadingDirection(value);
                        }
                      },
                    ),
                    RadioListTile<ReaderDirectionPreference>(
                      value: ReaderDirectionPreference.rtl,
                      groupValue: direction,
                      activeColor: AppTheme.primary,
                      title: const Text(
                        'Right to Left',
                        style: TextStyle(color: AppTheme.textPrimary),
                      ),
                      subtitle: const Text(
                        'Horizontal reader reverses page direction.',
                        style: TextStyle(
                          color: AppTheme.textSecond,
                          fontSize: 12,
                        ),
                      ),
                      onChanged: (value) {
                        if (value != null) {
                          AppSettingsService.setReadingDirection(value);
                        }
                      },
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          _buildSectionTitle('Theme'),
          Container(
            decoration: _sectionDecoration(),
            child: ValueListenableBuilder<ThemeMode>(
              valueListenable: AppSettingsService.themeModeNotifier,
              builder: (context, mode, _) {
                return Column(
                  children: [
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.system,
                      groupValue: mode,
                      activeColor: AppTheme.primary,
                      title: const Text(
                        'System',
                        style: TextStyle(color: AppTheme.textPrimary),
                      ),
                      onChanged: (value) {
                        if (value != null) {
                          AppSettingsService.setThemeMode(value);
                        }
                      },
                    ),
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.dark,
                      groupValue: mode,
                      activeColor: AppTheme.primary,
                      title: const Text(
                        'Dark',
                        style: TextStyle(color: AppTheme.textPrimary),
                      ),
                      onChanged: (value) {
                        if (value != null) {
                          AppSettingsService.setThemeMode(value);
                        }
                      },
                    ),
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.light,
                      groupValue: mode,
                      activeColor: AppTheme.primary,
                      title: const Text(
                        'Light',
                        style: TextStyle(color: AppTheme.textPrimary),
                      ),
                      onChanged: (value) {
                        if (value != null) {
                          AppSettingsService.setThemeMode(value);
                        }
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  BoxDecoration _sectionDecoration() {
    return BoxDecoration(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(14),
    );
  }

  Widget _buildSourcePicker({
    required String type,
    required String label,
    required Color accent,
  }) {
    final typedSources = _sources
        .where((source) => source['type']?.toString().toLowerCase() == type)
        .toList();

    return ValueListenableBuilder<Map<String, String>>(
      valueListenable: AppSettingsService.defaultSourcesNotifier,
      builder: (context, defaults, _) {
        final selectedId = defaults[type] ?? '';
        final selected = typedSources.any(
          (source) => source['id']?.toString() == selectedId,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: selected ? selectedId : null,
              dropdownColor: AppTheme.surface,
              iconEnabledColor: AppTheme.textPrimary,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              hint: Text(
                typedSources.isEmpty ? 'No $type sources found' : 'Select $type source',
                style: const TextStyle(color: AppTheme.textSecond, fontSize: 13),
              ),
              items: typedSources
                  .map(
                    (source) => DropdownMenuItem<String>(
                      value: source['id']?.toString() ?? '',
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              source['name']?.toString() ??
                                  source['id']?.toString() ??
                                  '',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: typedSources.isEmpty
                  ? null
                  : (value) async {
                      if (value == null || value.isEmpty) {
                        return;
                      }
                      await AppSettingsService.setDefaultSourceForType(type, value);
                      if (!mounted) {
                        return;
                      }
                      _showMessage('Default $type source updated');
                    },
            ),
          ],
        );
      },
    );
  }
}

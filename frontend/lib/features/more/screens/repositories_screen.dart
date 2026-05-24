import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';

class RepositoriesScreen extends StatefulWidget {
  const RepositoriesScreen({super.key});

  @override
  State<RepositoriesScreen> createState() => _RepositoriesScreenState();
}

class _RepositoriesScreenState extends State<RepositoriesScreen> {
  List<String> _repos = [];
  final _controller = TextEditingController();

  // Default repos
  final List<String> _defaultRepos = [
    'https://raw.githubusercontent.com/mark392a-ux/komiverse-extensions/main/index.json',
    'https://keiyoushi.github.io/extensions/index.min.json',
    'https://yuzono.github.io/extensions/index.min.json',
  ];

  @override
  void initState() {
    super.initState();
    _loadRepos();
  }

  Future<void> _loadRepos() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('repositories') ?? [];
    setState(() {
      _repos = saved.isEmpty ? List.from(_defaultRepos) : saved;
    });
    if (saved.isEmpty) _saveRepos();
  }

  Future<void> _saveRepos() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('repositories', _repos);
  }

  void _addRepo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text(
          'Add Repository',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: TextField(
          controller: _controller,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'https://example.com/index.json',
            hintStyle: const TextStyle(color: AppTheme.textSecond),
            filled: true,
            fillColor: AppTheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecond),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final url = _controller.text.trim();
              if (url.isNotEmpty && !_repos.contains(url)) {
                setState(() => _repos.add(url));
                _saveRepos();
                _controller.clear();
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _deleteRepo(int index) {
    setState(() => _repos.removeAt(index));
    _saveRepos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Repositories'),
        actions: [
          IconButton(icon: const Icon(Icons.add_rounded), onPressed: _addRepo),
        ],
      ),
      body: _repos.isEmpty
          ? const Center(
              child: Text(
                'No repositories added',
                style: TextStyle(color: AppTheme.textSecond),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _repos.length,
              itemBuilder: (context, index) {
                final repo = _repos[index];
                final isDefault = _defaultRepos.contains(repo);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.source_rounded,
                          color: AppTheme.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isDefault
                                  ? 'Default Repository'
                                  : 'Custom Repository',
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              repo,
                              style: const TextStyle(
                                color: AppTheme.textSecond,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (!isDefault)
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.red,
                            size: 20,
                          ),
                          onPressed: () => _deleteRepo(index),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

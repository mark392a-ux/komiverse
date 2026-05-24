import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_settings_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../models/anime_model.dart';
import '../widgets/anime_card.dart';

class AnimeListScreen extends StatefulWidget {
  const AnimeListScreen({super.key});

  @override
  State<AnimeListScreen> createState() => _AnimeListScreenState();
}

class _AnimeListScreenState extends State<AnimeListScreen>
    with SingleTickerProviderStateMixin {
  List<AnimeModel> _list = [];
  List<Map<String, dynamic>> _sources = [];
  Map<String, dynamic>? _selectedSource;
  bool _isLoading = true;
  String? _error;
  bool _isSearching = false;
  final TextEditingController _searchCtrl = TextEditingController();
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadSources();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSources() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await ApiClient.getSources();
      final all = (res.data['sources'] as List?) ?? [];
      final animeSources = all
          .where((s) => (s['type'] ?? '').toString().toLowerCase() == 'anime')
          .map((s) => s as Map<String, dynamic>)
          .toList();
      final preferredSourceId = AppSettingsService.defaultSourceForType('anime');
      Map<String, dynamic>? selected;
      if (preferredSourceId.isNotEmpty) {
        for (final source in animeSources) {
          if (source['id']?.toString() == preferredSourceId) {
            selected = source;
            break;
          }
        }
      }
      setState(() {
        _sources = animeSources;
        _selectedSource =
            selected ?? (animeSources.isNotEmpty ? animeSources.first : null);
      });
      if (_selectedSource != null) await _fetchList();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchList() async {
    if (_selectedSource == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    _fadeCtrl.reset();
    try {
      final res = await ApiClient.browse(
        sourceId: _selectedSource!['id'].toString(),
        sort: 'popular',
      );
      final items = (res.data['items'] as List?) ?? [];
      setState(() {
        _list = items
            .map(
              (e) => AnimeModel.fromJson(
                e as Map<String, dynamic>,
                sourceId: _selectedSource!['id'].toString(),
              ),
            )
            .toList();
        _isLoading = false;
      });
      _fadeCtrl.forward();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _doSearch(String q) async {
    if (_selectedSource == null || q.isEmpty) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    _fadeCtrl.reset();
    try {
      final res = await ApiClient.search(
        sourceId: _selectedSource!['id'].toString(),
        query: q,
      );
      final items = (res.data['items'] as List?) ?? [];
      setState(() {
        _list = items
            .map(
              (e) => AnimeModel.fromJson(
                e as Map<String, dynamic>,
                sourceId: _selectedSource!['id'].toString(),
              ),
            )
            .toList();
        _isLoading = false;
      });
      _fadeCtrl.forward();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        title: _isSearching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Search anime...',
                  hintStyle: TextStyle(color: AppTheme.textSecond),
                  border: InputBorder.none,
                ),
                onSubmitted: _doSearch,
              )
            : Row(
                children: [
                  const Text(
                    'Anime',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'ANIME',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close_rounded : Icons.search_rounded,
              color: AppTheme.textPrimary,
            ),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchCtrl.clear();
                  _fetchList();
                }
              });
            },
          ),
        ],
        bottom: _sources.length > 1
            ? PreferredSize(
                preferredSize: const Size.fromHeight(44),
                child: SizedBox(
                  height: 44,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    itemCount: _sources.length,
                    itemBuilder: (ctx, i) {
                      final selected =
                          _selectedSource?['id'] == _sources[i]['id'];
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedSource = _sources[i]);
                          AppSettingsService.setDefaultSourceForType(
                            'anime',
                            _sources[i]['id'].toString(),
                          );
                          _fetchList();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFF06B6D4)
                                : AppTheme.card,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _sources[i]['name'] ?? _sources[i]['id'],
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : AppTheme.textSecond,
                              fontSize: 12,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              )
            : null,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF06B6D4)),
      );
    }
    if (_error != null) {
      final cleanError = _cleanError(_error!);
      final consumetMissing =
          cleanError.toLowerCase().contains('consumet unreachable');
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                consumetMissing
                    ? Icons.extension_off_rounded
                    : Icons.wifi_off_rounded,
                color: AppTheme.textSecond,
                size: 56,
              ),
              const SizedBox(height: 12),
              if (consumetMissing) ...[
                const Text(
                  'Anime provider is offline',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
              ],
              Text(
                cleanError,
                style: const TextStyle(color: AppTheme.textSecond, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _fetchList,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                ),
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }
    if (_sources.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.play_circle_outline_rounded,
              size: 64,
              color: AppTheme.textSecond.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'No anime sources found',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add anime extensions from the Extensions tab',
              style: TextStyle(color: AppTheme.textSecond, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    if (_list.isEmpty) {
      return const Center(
        child: Text(
          'No anime found',
          style: TextStyle(color: AppTheme.textSecond),
        ),
      );
    }
    return FadeTransition(
      opacity: _fadeAnim,
      child: RefreshIndicator(
        color: const Color(0xFF06B6D4),
        backgroundColor: AppTheme.card,
        onRefresh: _fetchList,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
          itemCount: _list.length,
          itemBuilder: (ctx, i) {
            final anime = _list[i];
            return AnimeCard(
              anime: anime,
              onTap: () => context.push(
                '/anime/detail',
                extra: {'source': anime.source, 'id': anime.id, 'anime': anime},
              ),
            );
          },
        ),
      ),
    );
  }

  String _cleanError(String error) {
    if (error.startsWith('Exception: ')) {
      return error.substring('Exception: '.length).trim();
    }
    return error;
  }
}

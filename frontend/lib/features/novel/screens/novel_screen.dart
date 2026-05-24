import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/config/app_settings_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

class NovelScreen extends StatefulWidget {
  const NovelScreen({super.key});

  @override
  State<NovelScreen> createState() => _NovelScreenState();
}

class _NovelScreenState extends State<NovelScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _sources = [];
  Map<String, dynamic>? _selectedSource;
  List<Map<String, dynamic>> _novels = [];
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
      final novelSources = all
          .where((s) => (s['type'] ?? '').toString().toLowerCase() == 'novel')
          .map((s) => s as Map<String, dynamic>)
          .toList();
      final preferredSourceId = AppSettingsService.defaultSourceForType('novel');
      Map<String, dynamic>? selected;
      if (preferredSourceId.isNotEmpty) {
        for (final source in novelSources) {
          if (source['id']?.toString() == preferredSourceId) {
            selected = source;
            break;
          }
        }
      }
      setState(() {
        _sources = novelSources;
        _selectedSource =
            selected ?? (novelSources.isNotEmpty ? novelSources.first : null);
      });
      if (_selectedSource != null) {
        await _fetchNovels();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchNovels() async {
    if (_selectedSource == null) return;
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
        _novels = items.map((e) => e as Map<String, dynamic>).toList();
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
        _novels = items.map((e) => e as Map<String, dynamic>).toList();
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
                  hintText: 'Search novels...',
                  hintStyle: TextStyle(color: AppTheme.textSecond),
                  border: InputBorder.none,
                ),
                onSubmitted: _doSearch,
              )
            : Row(
                children: [
                  const Text(
                    'Novel',
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
                        colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'NOVEL',
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
                  _fetchNovels();
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
                            'novel',
                            _sources[i]['id'].toString(),
                          );
                          _fetchNovels();
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
                                ? const Color(0xFFF59E0B)
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
        child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
      );
    }
    if (_error != null) {
      final cleanError = _cleanError(_error!);
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              color: AppTheme.textSecond,
              size: 56,
            ),
            const SizedBox(height: 12),
            Text(
              cleanError,
              style: const TextStyle(color: AppTheme.textSecond, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _fetchNovels,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
              ),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
    if (_sources.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chrome_reader_mode_rounded,
                size: 72,
                color: AppTheme.textSecond.withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              const Text(
                'No novel sources installed',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add novel extensions from the Extensions tab',
                style: TextStyle(color: AppTheme.textSecond, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    if (_novels.isEmpty) {
      return const Center(
        child: Text(
          'No novels found',
          style: TextStyle(color: AppTheme.textSecond),
        ),
      );
    }
    return FadeTransition(
      opacity: _fadeAnim,
      child: RefreshIndicator(
        color: const Color(0xFFF59E0B),
        backgroundColor: AppTheme.card,
        onRefresh: _fetchNovels,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
          itemCount: _novels.length,
          itemBuilder: (ctx, i) {
            final novel = _novels[i];
            final cover =
                novel['cover'] ??
                novel['cover_url'] ??
                novel['thumbnail'] ??
                '';
            final title = novel['title'] ?? 'Untitled';
            final status = novel['status'] ?? '';
            final sourceId =
                novel['source']?.toString() ??
                _selectedSource?['id']?.toString() ??
                '';
            final id =
                novel['id']?.toString() ?? novel['url']?.toString() ?? '';
            return GestureDetector(
              onTap: () => context.push(
                '/novel/detail',
                extra: {
                  'source': sourceId,
                  'id': id,
                  'title': title,
                  'coverUrl': cover,
                },
              ),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(14),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: cover,
                        width: 80,
                        height: 110,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: 80,
                          height: 110,
                          color: AppTheme.surface,
                          child: const Icon(
                            Icons.book_outlined,
                            color: AppTheme.textSecond,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                height: 1.3,
                              ),
                            ),
                            if (status.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFF59E0B,
                                  ).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: const TextStyle(
                                    color: Color(0xFFF59E0B),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(right: 10),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: AppTheme.textSecond,
                        size: 22,
                      ),
                    ),
                  ],
                ),
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

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/config/app_settings_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../models/manga_model.dart';

/// A source entry from GET /api/sources
class _SourceEntry {
  final String id;
  final String name;
  final String type;
  _SourceEntry({required this.id, required this.name, required this.type});
}

class MangaListScreen extends StatefulWidget {
  const MangaListScreen({super.key});

  @override
  State<MangaListScreen> createState() => _MangaListScreenState();
}

class _MangaListScreenState extends State<MangaListScreen>
    with SingleTickerProviderStateMixin {
  List<MangaModel> _mangaList = [];
  List<_SourceEntry> _sources = [];
  _SourceEntry? _selectedSource;
  bool _isLoading = true;
  String? _error;
  String _search = '';
  String _sort = 'popular';
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
      final rawList = (res.data['sources'] as List?) ?? [];
      final mangaSources = rawList
          .where((s) => (s['type'] ?? '').toString().toLowerCase() == 'manga')
          .map(
            (s) => _SourceEntry(
              id: s['id'].toString(),
              name: s['name'] ?? s['id'],
              type: s['type'] ?? 'manga',
            ),
          )
          .toList();
      final preferredSourceId = AppSettingsService.defaultSourceForType('manga');
      _SourceEntry? selected;
      if (preferredSourceId.isNotEmpty) {
        for (final source in mangaSources) {
          if (source.id == preferredSourceId) {
            selected = source;
            break;
          }
        }
      }
      setState(() {
        _sources = mangaSources;
        _selectedSource =
            selected ?? (mangaSources.isNotEmpty ? mangaSources.first : null);
      });
      if (_selectedSource != null) await _fetchManga();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchManga() async {
    if (_selectedSource == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    _fadeCtrl.reset();
    try {
      final res = await ApiClient.browse(
        sourceId: _selectedSource!.id,
        sort: _sort,
      );
      final items = (res.data['items'] as List?) ?? [];
      setState(() {
        _mangaList = items
            .map(
              (e) => MangaModel.fromJson(
                e as Map<String, dynamic>,
                sourceId: _selectedSource!.id,
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
        sourceId: _selectedSource!.id,
        query: q,
      );
      final items = (res.data['items'] as List?) ?? [];
      setState(() {
        _mangaList = items
            .map(
              (e) => MangaModel.fromJson(
                e as Map<String, dynamic>,
                sourceId: _selectedSource!.id,
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
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildSliverAppBar(innerBoxIsScrolled),
        ],
        body: _buildBody(),
      ),
    );
  }

  Widget _buildSliverAppBar(bool collapsed) {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      snap: true,
      pinned: false,
      backgroundColor: AppTheme.background,
      elevation: 0,
      title: _isSearching
          ? TextField(
              controller: _searchCtrl,
              autofocus: true,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
              decoration: const InputDecoration(
                hintText: 'Search manga...',
                hintStyle: TextStyle(color: AppTheme.textSecond),
                border: InputBorder.none,
              ),
              onSubmitted: (v) {
                _search = v;
                _doSearch(v);
              },
            )
          : Row(
              children: [
                const Text(
                  'KomiVerse',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primary, Color(0xFF7B2FBE)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'MANGA',
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
                _search = '';
                _fetchManga();
              }
            });
          },
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.sort_rounded, color: AppTheme.textPrimary),
          color: AppTheme.card,
          onSelected: (v) {
            _sort = v;
            _fetchManga();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'popular',
              child: Text(
                'Popular',
                style: TextStyle(color: AppTheme.textPrimary),
              ),
            ),
            const PopupMenuItem(
              value: 'latest',
              child: Text(
                'Latest',
                style: TextStyle(color: AppTheme.textPrimary),
              ),
            ),
          ],
        ),
      ],
      bottom: _sources.length > 1
          ? PreferredSize(
              preferredSize: const Size.fromHeight(44),
              child: _buildSourceTabs(),
            )
          : null,
    );
  }

  Widget _buildSourceTabs() {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: _sources.length,
        itemBuilder: (context, i) {
          final s = _sources[i];
          final selected = _selectedSource?.id == s.id;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedSource = s);
              AppSettingsService.setDefaultSourceForType('manga', s.id);
              _fetchManga();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? AppTheme.primary : AppTheme.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? AppTheme.primary : AppTheme.surface,
                ),
              ),
              child: Text(
                s.name,
                style: TextStyle(
                  color: selected ? Colors.white : AppTheme.textSecond,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: AppTheme.primary,
              strokeWidth: 2.5,
            ),
            const SizedBox(height: 16),
            Text(
              'Loading manga...',
              style: TextStyle(
                color: AppTheme.textSecond.withOpacity(0.7),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      final isConnectivityIssue = _isConnectivityError(_error!);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isConnectivityIssue
                    ? Icons.wifi_off_rounded
                    : Icons.warning_amber_rounded,
                color: AppTheme.textSecond,
                size: 56,
              ),
              const SizedBox(height: 16),
              Text(
                isConnectivityIssue
                    ? 'Cannot reach backend'
                    : 'Source is unavailable',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _cleanError(_error!),
                style: const TextStyle(
                  color: AppTheme.textSecond,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadSources,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_mangaList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book_outlined,
              color: AppTheme.textSecond.withOpacity(0.3),
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'No manga found',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try a different source or search term',
              style: TextStyle(color: AppTheme.textSecond, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnim,
      child: RefreshIndicator(
        color: AppTheme.primary,
        backgroundColor: AppTheme.card,
        onRefresh: _search.isNotEmpty ? () => _doSearch(_search) : _fetchManga,
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.52,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: _mangaList.length,
          itemBuilder: (context, index) {
            final manga = _mangaList[index];
            return _MangaCard(
              manga: manga,
              onTap: () => context.push(
                '/manga/detail',
                extra: {'source': manga.source, 'id': manga.id, 'manga': manga},
              ),
            );
          },
        ),
      ),
    );
  }

  bool _isConnectivityError(String error) {
    final lower = error.toLowerCase();
    return lower.contains('cannot reach server') ||
        lower.contains('connection timed out') ||
        lower.contains('socketexception') ||
        lower.contains('failed host lookup');
  }

  String _cleanError(String error) {
    if (error.startsWith('Exception: ')) {
      return error.substring('Exception: '.length).trim();
    }
    return error;
  }
}

// ── Premium Manga Card ─────────────────────────────────────────────────────
class _MangaCard extends StatefulWidget {
  final MangaModel manga;
  final VoidCallback onTap;
  const _MangaCard({required this.manga, required this.onTap});

  @override
  State<_MangaCard> createState() => _MangaCardState();
}

class _MangaCardState extends State<_MangaCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(
      begin: 1,
      end: 0.94,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'ongoing':
        return const Color(0xFF22C55E);
      case 'completed':
        return const Color(0xFF3B82F6);
      case 'hiatus':
        return const Color(0xFFF59E0B);
      default:
        return AppTheme.textSecond;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Cover
              CachedNetworkImage(
                imageUrl: widget.manga.coverUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: AppTheme.surface,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primary,
                      strokeWidth: 1.5,
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: AppTheme.surface,
                  child: const Center(
                    child: Icon(
                      Icons.menu_book_outlined,
                      color: AppTheme.textSecond,
                      size: 32,
                    ),
                  ),
                ),
              ),
              // Dark gradient overlay
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.45, 1.0],
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
              ),
              // Status dot
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _statusColor(widget.manga.status),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _statusColor(
                          widget.manga.status,
                        ).withOpacity(0.6),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
              // Title at bottom
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
                  child: Text(
                    widget.manga.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                      shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

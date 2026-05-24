import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../models/manga_model.dart';
import '../models/chapter_model.dart';

class MangaDetailScreen extends StatefulWidget {
  final String source;
  final String id;
  final MangaModel? preloaded; // passed via router extra for instant header

  const MangaDetailScreen({
    super.key,
    required this.source,
    required this.id,
    this.preloaded,
  });

  @override
  State<MangaDetailScreen> createState() => _MangaDetailScreenState();
}

class _MangaDetailScreenState extends State<MangaDetailScreen> {
  MangaModel? _manga;
  List<ChapterModel> _chapters = [];
  bool _isLoading = true;
  String? _error;
  bool _descExpanded = false;

  @override
  void initState() {
    super.initState();
    _manga = widget.preloaded;
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final infoFut = ApiClient.info(sourceId: widget.source, id: widget.id);
      final chapsFut = ApiClient.chapters(
        sourceId: widget.source,
        id: widget.id,
      );
      final results = await Future.wait([infoFut, chapsFut]);

      final infoData = results[0].data;
      final chapsData = results[1].data;

      // Info can be wrapped in a 'data' key or directly at root
      final rawInfo = infoData['data'] ?? infoData;
      final rawChaps =
          (chapsData['chapters'] as List?) ??
          (chapsData['data'] as List?) ??
          [];

      setState(() {
        _manga = MangaModel.fromJson(
          rawInfo is Map<String, dynamic> ? rawInfo : {},
          sourceId: widget.source,
        );
        _chapters = rawChaps
            .map(
              (c) => ChapterModel.fromJson(
                c as Map<String, dynamic>,
                sourceId: widget.source,
              ),
            )
            .toList();
        _isLoading = false;
      });
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
      body: _error != null && _manga == null
          ? _buildError()
          : CustomScrollView(
              slivers: [
                _buildHeader(),
                _buildInfo(),
                _buildChapterHeader(),
                _buildChapterList(),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    final cover = _manga?.coverUrl ?? '';
    return SliverAppBar(
      expandedHeight: 320,
      pinned: true,
      backgroundColor: AppTheme.background,
      leading: GestureDetector(
        onTap: () => context.pop(),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (cover.isNotEmpty)
              CachedNetworkImage(
                imageUrl: cover,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(color: AppTheme.surface),
              )
            else
              Container(color: AppTheme.surface),
            // Blur-style gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.transparent,
                    AppTheme.background.withOpacity(0.85),
                    AppTheme.background,
                  ],
                  stops: const [0, 0.35, 0.75, 1],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfo() {
    if (_manga == null) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(color: AppTheme.primary),
          ),
        ),
      );
    }
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              _manga!.title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            // Chips row
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _Chip(
                  label: _manga!.status.toUpperCase(),
                  color: _statusColor(_manga!.status),
                ),
                _Chip(
                  label: _manga!.type.toUpperCase(),
                  color: AppTheme.primary,
                ),
                if (_chapters.isNotEmpty)
                  _Chip(
                    label: '${_chapters.length} CH',
                    color: const Color(0xFF06B6D4),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            // Description
            if (_manga!.description.isNotEmpty) ...[
              GestureDetector(
                onTap: () => setState(() => _descExpanded = !_descExpanded),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 250),
                      firstChild: Text(
                        _manga!.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textSecond,
                          fontSize: 13.5,
                          height: 1.6,
                        ),
                      ),
                      secondChild: Text(
                        _manga!.description,
                        style: const TextStyle(
                          color: AppTheme.textSecond,
                          fontSize: 13.5,
                          height: 1.6,
                        ),
                      ),
                      crossFadeState: _descExpanded
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _descExpanded ? 'Show less ▲' : 'Read more ▼',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            // Start Reading button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _chapters.isNotEmpty
                    ? () => _openChapter(_chapters.first)
                    : null,
                icon: const Icon(Icons.menu_book_rounded, size: 20),
                label: Text(
                  _isLoading ? 'Loading chapters…' : 'Start Reading',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppTheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChapterHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Row(
          children: [
            const Text(
              'Chapters',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            if (_isLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: AppTheme.primary,
                  strokeWidth: 2,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChapterList() {
    if (_chapters.isEmpty && _isLoading) {
      return const SliverToBoxAdapter(child: SizedBox());
    }
    if (_chapters.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(
                  Icons.library_books_outlined,
                  size: 48,
                  color: AppTheme.textSecond.withOpacity(0.4),
                ),
                const SizedBox(height: 12),
                const Text(
                  'No chapters available',
                  style: TextStyle(color: AppTheme.textSecond),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final ch = _chapters[index];
        return _ChapterTile(
          chapter: ch,
          index: index,
          onTap: () => _openChapter(ch),
        );
      }, childCount: _chapters.length),
    );
  }

  void _openChapter(ChapterModel ch) {
    context.push(
      '/manga/read',
      extra: {
        'source': widget.source,
        'id': ch.id,
        'mangaId': widget.id,
        'title': ch.displayTitle,
        'mangaTitle': _manga?.title ?? '',
      },
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.red,
              size: 56,
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to load manga',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: AppTheme.textSecond, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchData,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.pop(),
              child: const Text(
                'Go back',
                style: TextStyle(color: AppTheme.textSecond),
              ),
            ),
          ],
        ),
      ),
    );
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
}

// ── Reusable chip ─────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ── Chapter Tile ──────────────────────────────────────────────────────────
class _ChapterTile extends StatelessWidget {
  final ChapterModel chapter;
  final int index;
  final VoidCallback onTap;

  const _ChapterTile({
    required this.chapter,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: index.isEven
              ? AppTheme.card.withOpacity(0.6)
              : Colors.transparent,
          border: const Border(
            bottom: BorderSide(color: Color(0xFF1A3D50), width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  chapter.number % 1 == 0
                      ? chapter.number.toInt().toString()
                      : chapter.number.toString(),
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                chapter.displayTitle,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textSecond,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/history/services/history_service.dart';
import '../models/anime_model.dart';

class AnimeDetailScreen extends StatefulWidget {
  final String source;
  final String id;
  final AnimeModel? preloaded;

  const AnimeDetailScreen({
    super.key,
    required this.source,
    required this.id,
    this.preloaded,
  });

  @override
  State<AnimeDetailScreen> createState() => _AnimeDetailScreenState();
}

class _AnimeDetailScreenState extends State<AnimeDetailScreen> {
  AnimeModel? _anime;
  List<Map<String, dynamic>> _episodes = [];
  bool _isLoading = true;
  String? _error;
  bool _descExpanded = false;

  @override
  void initState() {
    super.initState();
    _anime = widget.preloaded;
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final infoFuture = ApiClient.info(sourceId: widget.source, id: widget.id);
      final episodesFuture = ApiClient.chapters(
        sourceId: widget.source,
        id: widget.id,
      );
      final results = await Future.wait([infoFuture, episodesFuture]);

      final rawInfo = results[0].data['data'] ?? results[0].data;
      final rawEpisodes =
          (results[1].data['chapters'] as List?) ??
          (results[1].data['episodes'] as List?) ??
          (results[1].data['data'] as List?) ??
          [];

      if (!mounted) {
        return;
      }
      setState(() {
        _anime = AnimeModel.fromJson(
          rawInfo is Map<String, dynamic> ? rawInfo : {},
          sourceId: widget.source,
        );
        _episodes = rawEpisodes.map((e) => e as Map<String, dynamic>).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  int _episodeNumber(Map<String, dynamic> ep, int index) {
    final raw = ep['number'] ?? ep['episode_number'] ?? ep['episode'] ?? 0;
    if (raw is num) {
      return raw.toInt();
    }
    return int.tryParse(raw.toString()) ?? (index + 1);
  }

  void _watchEpisode(Map<String, dynamic> ep, int index) {
    final epId = ep['id']?.toString() ?? ep['url']?.toString() ?? '';
    final number = _episodeNumber(ep, index);
    final title = ep['title']?.toString().isNotEmpty == true
        ? ep['title'].toString()
        : 'Episode $number';

    HistoryService.addEntry(
      HistoryEntry(
        title: _anime?.title ?? title,
        coverUrl: _anime?.coverUrl ?? '',
        sourceId: widget.source,
        itemId: widget.id,
        type: 'anime',
        progress: 'Ep $number/${_episodes.length}',
      ),
    );

    context.push(
      '/anime/watch',
      extra: {
        'source': widget.source,
        'id': epId.isNotEmpty ? epId : widget.id,
        'animeId': widget.id,
        'title': title,
        'animeTitle': _anime?.title ?? '',
        'index': index,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: _error != null && _anime == null
          ? _buildError()
          : CustomScrollView(
              slivers: [
                _buildHeader(),
                _buildInfo(),
                _buildEpisodesHeader(),
                _buildEpisodeList(),
              ],
            ),
    );
  }

  SliverAppBar _buildHeader() {
    return SliverAppBar(
      expandedHeight: 300,
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
            if (_anime?.coverUrl.isNotEmpty == true)
              CachedNetworkImage(
                imageUrl: _anime!.coverUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(color: AppTheme.surface),
              )
            else
              Container(
                color: AppTheme.surface,
                child: const Icon(
                  Icons.play_circle_outline_rounded,
                  color: AppTheme.textSecond,
                  size: 80,
                ),
              ),
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

  SliverToBoxAdapter _buildInfo() {
    if (_anime == null) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(color: Color(0xFF06B6D4)),
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
            Text(
              _anime!.title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _Chip(
                  label: _anime!.status.toUpperCase(),
                  color: const Color(0xFF22C55E),
                ),
                if (_anime!.totalEpisodes > 0)
                  _Chip(
                    label: '${_anime!.totalEpisodes} EPS',
                    color: const Color(0xFF06B6D4),
                  ),
                _Chip(label: 'ANIME', color: AppTheme.primary),
              ],
            ),
            const SizedBox(height: 14),
            if (_anime!.description.isNotEmpty)
              GestureDetector(
                onTap: () => setState(() => _descExpanded = !_descExpanded),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 250),
                      firstChild: Text(
                        _anime!.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textSecond,
                          fontSize: 13.5,
                          height: 1.6,
                        ),
                      ),
                      secondChild: Text(
                        _anime!.description,
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
                      _descExpanded ? 'Show less' : 'Read more',
                      style: const TextStyle(
                        color: Color(0xFF06B6D4),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _episodes.isNotEmpty
                    ? () => _watchEpisode(_episodes.first, 0)
                    : null,
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                label: Text(
                  _isLoading ? 'Loading episodes...' : 'Start Watching',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF06B6D4),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppTheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildEpisodesHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Row(
          children: [
            const Text(
              'Episodes',
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
                  color: Color(0xFF06B6D4),
                  strokeWidth: 2,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEpisodeList() {
    if (_episodes.isEmpty && _isLoading) {
      return const SliverToBoxAdapter(child: SizedBox());
    }

    if (_episodes.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(
                  Icons.video_library_outlined,
                  size: 48,
                  color: AppTheme.textSecond.withOpacity(0.4),
                ),
                const SizedBox(height: 12),
                const Text(
                  'No episodes available',
                  style: TextStyle(color: AppTheme.textSecond),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((ctx, i) {
        final ep = _episodes[i];
        final number = _episodeNumber(ep, i);
        final title = ep['title']?.toString().isNotEmpty == true
            ? ep['title'].toString()
            : 'Episode $number';

        return InkWell(
          onTap: () => _watchEpisode(ep, i),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: i.isEven
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
                    color: const Color(0xFF06B6D4).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '$number',
                      style: const TextStyle(
                        color: Color(0xFF06B6D4),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(
                  Icons.play_circle_outline_rounded,
                  color: Color(0xFF06B6D4),
                  size: 22,
                ),
              ],
            ),
          ),
        );
      }, childCount: _episodes.length),
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
              'Failed to load anime',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              style: const TextStyle(color: AppTheme.textSecond, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF06B6D4),
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
}

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

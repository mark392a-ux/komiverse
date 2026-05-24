import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

class NovelDetailScreen extends StatefulWidget {
  final String source;
  final String id;
  final String title;
  final String coverUrl;

  const NovelDetailScreen({
    super.key,
    required this.source,
    required this.id,
    required this.title,
    required this.coverUrl,
  });

  @override
  State<NovelDetailScreen> createState() => _NovelDetailScreenState();
}

class _NovelDetailScreenState extends State<NovelDetailScreen> {
  Map<String, dynamic>? _info;
  List<_NovelChapter> _chapters = [];
  bool _isLoading = true;
  String? _error;
  bool _descExpanded = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final infoFuture = ApiClient.info(sourceId: widget.source, id: widget.id);
      final chaptersFuture = ApiClient.chapters(
        sourceId: widget.source,
        id: widget.id,
      );
      final results = await Future.wait([infoFuture, chaptersFuture]);

      final infoData = results[0].data;
      final chaptersData = results[1].data;

      final rootInfo = infoData is Map<String, dynamic>
          ? infoData
          : <String, dynamic>{};
      final infoMap = (rootInfo['data'] is Map<String, dynamic>)
          ? rootInfo['data'] as Map<String, dynamic>
          : rootInfo;
      final rawChapters =
          (chaptersData['chapters'] as List?) ??
          (chaptersData['data'] as List?) ??
          [];

      final chapters = rawChapters
          .map((e) => _NovelChapter.fromJson(e as Map<String, dynamic>))
          .toList();

      if (!mounted) {
        return;
      }
      setState(() {
        _info = infoMap;
        _chapters = chapters;
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

  @override
  Widget build(BuildContext context) {
    final title = (_info?['title'] ?? widget.title).toString().trim();
    final displayTitle = title.isNotEmpty ? title : 'Novel';
    final description = (_info?['description'] ?? '').toString();
    final status = (_info?['status'] ?? '').toString();
    final cover =
        (_info?['cover'] ??
                _info?['cover_url'] ??
                _info?['thumbnail'] ??
                widget.coverUrl)
            .toString();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 18),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
            )
          : _error != null
          ? _buildError()
          : RefreshIndicator(
              onRefresh: _fetchData,
              color: const Color(0xFFF59E0B),
              backgroundColor: AppTheme.card,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  if (cover.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: cover,
                        height: 190,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          height: 190,
                          color: AppTheme.surface,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.book_outlined,
                            color: AppTheme.textSecond,
                            size: 34,
                          ),
                        ),
                      ),
                    ),
                  if (status.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFFF59E0B),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _descExpanded = !_descExpanded),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            description,
                            maxLines: _descExpanded ? null : 4,
                            overflow: _descExpanded
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textSecond,
                              height: 1.55,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _descExpanded ? 'Show less' : 'Read more',
                            style: const TextStyle(
                              color: Color(0xFFF59E0B),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _chapters.isNotEmpty
                          ? () => _openChapter(_chapters.first)
                          : null,
                      icon: const Icon(Icons.chrome_reader_mode_rounded),
                      label: Text(
                        _chapters.isNotEmpty
                            ? 'Start Reading'
                            : 'No Chapters Available',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppTheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      const Text(
                        'Chapters',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_chapters.length}',
                        style: const TextStyle(
                          color: AppTheme.textSecond,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_chapters.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'No chapters found for this novel.',
                        style: TextStyle(color: AppTheme.textSecond),
                      ),
                    )
                  else
                    ..._chapters.asMap().entries.map((entry) {
                      final index = entry.key;
                      final chapter = entry.value;
                      return InkWell(
                        onTap: () => _openChapter(chapter),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: index.isEven
                                ? AppTheme.card.withOpacity(0.6)
                                : Colors.transparent,
                            border: const Border(
                              bottom: BorderSide(
                                color: Color(0xFF1A3D50),
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
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
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }

  void _openChapter(_NovelChapter chapter) {
    final title = (_info?['title'] ?? widget.title).toString();
    context.push(
      '/novel/read',
      extra: {
        'source': widget.source,
        'novelId': widget.id,
        'id': chapter.id,
        'title': chapter.displayTitle,
        'novelTitle': title,
      },
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.red,
              size: 52,
            ),
            const SizedBox(height: 12),
            const Text(
              'Failed to load novel',
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
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NovelChapter {
  final String id;
  final String title;
  final String number;

  _NovelChapter({required this.id, required this.title, required this.number});

  factory _NovelChapter.fromJson(Map<String, dynamic> json) {
    return _NovelChapter(
      id: json['id']?.toString() ?? json['url']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      number: json['number']?.toString() ?? '',
    );
  }

  String get displayTitle {
    if (title.trim().isNotEmpty) {
      return title;
    }
    if (number.trim().isNotEmpty) {
      return 'Chapter $number';
    }
    return 'Chapter';
  }
}

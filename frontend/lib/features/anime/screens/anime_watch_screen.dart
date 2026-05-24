import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/history/services/history_service.dart';

class AnimeWatchScreen extends StatefulWidget {
  final String source;
  final String id; // episode id from chapter list
  final String animeId; // series id
  final String title;
  final String animeTitle;
  final int index;

  const AnimeWatchScreen({
    super.key,
    required this.source,
    required this.id,
    required this.animeId,
    required this.title,
    required this.animeTitle,
    required this.index,
  });

  @override
  State<AnimeWatchScreen> createState() => _AnimeWatchScreenState();
}

class _AnimeWatchScreenState extends State<AnimeWatchScreen> {
  bool _saved = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _saveHistoryOnce();
  }

  Future<void> _saveHistoryOnce() async {
    if (_saved) {
      return;
    }
    _saved = true;
    await HistoryService.addEntry(
      HistoryEntry(
        title: widget.animeTitle.isNotEmpty ? widget.animeTitle : widget.title,
        coverUrl: '',
        sourceId: widget.source,
        itemId: widget.animeId.isNotEmpty ? widget.animeId : widget.id,
        type: 'anime',
        progress: widget.title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayTitle = widget.animeTitle.isNotEmpty
        ? widget.animeTitle
        : 'Anime Episode';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFF06B6D4).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.live_tv_rounded,
                  color: Color(0xFF06B6D4),
                  size: 34,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Streaming is not available from this backend yet.\nConnect a stream URL source to enable playback.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textSecond,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.push(
                    '/anime/detail',
                    extra: {
                      'source': widget.source,
                      'id': widget.animeId.isNotEmpty
                          ? widget.animeId
                          : widget.id,
                    },
                  ),
                  icon: const Icon(Icons.list_alt_rounded),
                  label: const Text('Back to Episodes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06B6D4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text(
                  'Close',
                  style: TextStyle(color: AppTheme.textSecond),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

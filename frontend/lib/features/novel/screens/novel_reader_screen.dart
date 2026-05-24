import 'package:flutter/material.dart';
import '../../../core/config/app_settings_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/history/services/history_service.dart';

class NovelReaderScreen extends StatefulWidget {
  final String source;
  final String novelId; // series id
  final String id;
  final String chapterTitle;
  final String novelTitle;

  const NovelReaderScreen({
    super.key,
    required this.source,
    required this.novelId,
    required this.id,
    required this.chapterTitle,
    required this.novelTitle,
  });

  @override
  State<NovelReaderScreen> createState() => _NovelReaderScreenState();
}

class _NovelReaderScreenState extends State<NovelReaderScreen> {
  bool _isLoading = true;
  String? _error;
  String _content = '';

  @override
  void initState() {
    super.initState();
    _fetchContent();
  }

  Future<void> _fetchContent() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await ApiClient.pages(sourceId: widget.source, id: widget.id);
      final rawPages = (res.data['pages'] as List?) ?? [];
      if (rawPages.isEmpty) {
        throw Exception('No chapter content found.');
      }

      final raw = rawPages.first.toString();
      final text = _htmlToPlainText(raw);

      if (!mounted) {
        return;
      }

      await HistoryService.addEntry(
        HistoryEntry(
          title: widget.novelTitle.isNotEmpty
              ? widget.novelTitle
              : widget.chapterTitle,
          coverUrl: '',
          sourceId: widget.source,
          itemId: widget.novelId.isNotEmpty ? widget.novelId : widget.id,
          type: 'novel',
          progress: widget.chapterTitle,
        ),
      );

      setState(() {
        _content = text.trim();
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
    final isRtl =
        AppSettingsService.readingDirectionNotifier.value ==
        ReaderDirectionPreference.rtl;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.novelTitle.isNotEmpty)
              Text(
                widget.novelTitle,
                style: const TextStyle(
                  color: AppTheme.textSecond,
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            Text(
              widget.chapterTitle,
              style: const TextStyle(fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
            )
          : _error != null
          ? _buildError()
          : _content.isEmpty
          ? const Center(
              child: Text(
                'No readable content in this chapter.',
                style: TextStyle(color: AppTheme.textSecond),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
              child: SelectableText(
                _content,
                textAlign: isRtl ? TextAlign.right : TextAlign.left,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  height: 1.9,
                ),
              ),
            ),
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
              'Failed to load chapter',
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
              onPressed: _fetchContent,
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

  String _htmlToPlainText(String html) {
    var text = html;

    text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n');
    text = text.replaceAll(RegExp(r'<p[^>]*>', caseSensitive: false), '');

    text = text.replaceAll(RegExp(r'<[^>]+>'), '');

    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');

    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }
}

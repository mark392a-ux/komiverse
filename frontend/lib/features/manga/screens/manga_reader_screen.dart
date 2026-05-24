import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/config/app_settings_service.dart';
import '../../../features/history/services/history_service.dart';

class MangaReaderScreen extends StatefulWidget {
  final String source;
  final String id; // chapter id
  final String mangaId; // series id
  final String chapterTitle;
  final String mangaTitle;

  const MangaReaderScreen({
    super.key,
    required this.source,
    required this.id,
    required this.mangaId,
    required this.chapterTitle,
    required this.mangaTitle,
  });

  @override
  State<MangaReaderScreen> createState() => _MangaReaderScreenState();
}

class _MangaReaderScreenState extends State<MangaReaderScreen>
    with SingleTickerProviderStateMixin {
  List<String> _pages = [];
  bool _isLoading = true;
  bool _showUI = true;
  int _currentPage = 0;
  String? _error;
  bool _isVertical = true;
  bool _isRtl = false;

  final PageController _pageCtrl = PageController();
  final ScrollController _scrollCtrl = ScrollController();

  late AnimationController _uiAnim;
  late Animation<double> _uiFade;

  String get _progressKey =>
      'progress_${widget.source}_${widget.mangaId}_${widget.id}';

  @override
  void initState() {
    super.initState();
    _isRtl =
        AppSettingsService.readingDirectionNotifier.value ==
        ReaderDirectionPreference.rtl;
    AppSettingsService.readingDirectionNotifier.addListener(
      _onReadingDirectionChanged,
    );
    _uiAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _uiFade = CurvedAnimation(parent: _uiAnim, curve: Curves.easeOut);
    _uiAnim.value = 1.0;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _fetchPages();
    _loadProgress();
  }

  @override
  void dispose() {
    AppSettingsService.readingDirectionNotifier.removeListener(
      _onReadingDirectionChanged,
    );
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pageCtrl.dispose();
    _scrollCtrl.dispose();
    _uiAnim.dispose();
    super.dispose();
  }

  void _onReadingDirectionChanged() {
    final isRtl =
        AppSettingsService.readingDirectionNotifier.value ==
        ReaderDirectionPreference.rtl;
    if (mounted) {
      setState(() => _isRtl = isRtl);
    }
  }

  Future<void> _fetchPages() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await ApiClient.pages(sourceId: widget.source, id: widget.id);
      final rawPages =
          (res.data['pages'] as List?) ?? (res.data['images'] as List?) ?? [];
      final pages = rawPages.map((e) => e.toString()).toList();
      setState(() {
        _pages = pages;
        _isLoading = false;
      });
      // Write history entry
      if (pages.isNotEmpty) {
        await HistoryService.addEntry(
          HistoryEntry(
            title: widget.mangaTitle.isNotEmpty
                ? widget.mangaTitle
                : widget.chapterTitle,
            coverUrl: '',
            sourceId: widget.source,
            itemId: widget.mangaId.isNotEmpty ? widget.mangaId : widget.id,
            type: 'manga',
            progress: '${_currentPage + 1}/${pages.length}',
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProgress(int page) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_progressKey, page);
    // update history progress
    await HistoryService.addEntry(
      HistoryEntry(
        title: widget.mangaTitle.isNotEmpty
            ? widget.mangaTitle
            : widget.chapterTitle,
        coverUrl: '',
        sourceId: widget.source,
        itemId: widget.mangaId.isNotEmpty ? widget.mangaId : widget.id,
        type: 'manga',
        progress: '${page + 1}/${_pages.length}',
      ),
    );
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_progressKey);
    if (saved != null && saved > 0) {
      setState(() => _currentPage = saved);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isVertical && _scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            saved * 800.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else if (_pageCtrl.hasClients) {
          _pageCtrl.jumpToPage(saved);
        }
      });
    }
  }

  void _toggleUI() {
    setState(() => _showUI = !_showUI);
    if (_showUI) {
      _uiAnim.forward();
    } else {
      _uiAnim.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          else if (_error != null)
            _buildError()
          else if (_pages.isEmpty)
            _buildNoPages()
          else
            _isVertical ? _buildVertical() : _buildHorizontal(),

          // Animated overlays
          FadeTransition(opacity: _uiFade, child: _buildTopBar()),
          if (_pages.isNotEmpty)
            FadeTransition(opacity: _uiFade, child: _buildBottomBar()),
        ],
      ),
    );
  }

  Widget _buildVertical() {
    return GestureDetector(
      onTap: _toggleUI,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (_pages.isEmpty) return false;
          if (notification is ScrollUpdateNotification &&
              _scrollCtrl.hasClients) {
            final page = (_scrollCtrl.offset / 800.0).round().clamp(
              0,
              _pages.length - 1,
            );
            if (page != _currentPage) {
              setState(() => _currentPage = page);
              _saveProgress(page);
            }
          }
          return false;
        },
        child: ListView.builder(
          controller: _scrollCtrl,
          itemCount: _pages.length,
          itemBuilder: (ctx, i) => _buildPage(i),
        ),
      ),
    );
  }

  Widget _buildHorizontal() {
    final imageHeaders = _imageHeadersForSource();
    return GestureDetector(
      onTap: _toggleUI,
      child: PhotoViewGallery.builder(
        pageController: _pageCtrl,
        itemCount: _pages.length,
        reverse: _isRtl,
        onPageChanged: (i) {
          setState(() => _currentPage = i);
          _saveProgress(i);
        },
        builder: (ctx, i) => PhotoViewGalleryPageOptions(
          imageProvider: NetworkImage(_pages[i], headers: imageHeaders),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 3,
        ),
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        loadingBuilder: (_, __) => const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
      ),
    );
  }

  Widget _buildPage(int i) {
    final imageHeaders = _imageHeadersForSource();
    return GestureDetector(
      onTap: _toggleUI,
      child: Image.network(
        _pages[i],
        headers: imageHeaders,
        width: double.infinity,
        fit: BoxFit.fitWidth,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return Container(
            height: 400,
            color: const Color(0xFF0A1F29),
            child: Center(
              child: CircularProgressIndicator(
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded /
                          progress.expectedTotalBytes!
                    : null,
                color: AppTheme.primary,
                strokeWidth: 2,
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => Container(
          height: 300,
          color: const Color(0xFF0A1F29),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.broken_image_rounded,
                color: AppTheme.textSecond,
                size: 40,
              ),
              const SizedBox(height: 8),
              Text(
                'Page ${i + 1} failed to load',
                style: const TextStyle(
                  color: AppTheme.textSecond,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, String>? _imageHeadersForSource() {
    String? referer;
    switch (widget.source) {
      case 'toonily':
        referer = 'https://toonily.com/';
        break;
      case 'mangageko':
        referer = 'https://www.mgeko.cc/';
        break;
      case 'manhwaz':
        referer = 'https://manhwaz.com/';
        break;
      case 'thunderscans':
        referer = 'https://en-thunderscans.com/';
        break;
      default:
        break;
    }
    if (referer == null) {
      return null;
    }
    return {
      'Referer': referer,
      'User-Agent': 'Mozilla/5.0',
    };
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.mangaTitle.isNotEmpty)
                        Text(
                          widget.mangaTitle,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      Text(
                        widget.chapterTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Mode toggle
                IconButton(
                  tooltip: _isVertical
                      ? 'Switch to horizontal'
                      : 'Switch to vertical',
                  icon: Icon(
                    _isVertical
                        ? Icons.swap_horiz_rounded
                        : Icons.swap_vert_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () => setState(() => _isVertical = !_isVertical),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final total = _pages.length;
    if (total == 0) return const SizedBox();
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_currentPage + 1} / $total',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppTheme.primary,
                inactiveTrackColor: Colors.white24,
                thumbColor: AppTheme.primary,
                overlayColor: AppTheme.primary.withOpacity(0.2),
                trackHeight: 3,
              ),
              child: Slider(
                value: _currentPage.toDouble().clamp(0, (total - 1).toDouble()),
                min: 0,
                max: (total - 1).toDouble(),
                onChanged: (v) {
                  final page = v.toInt();
                  setState(() => _currentPage = page);
                  _saveProgress(page);
                  if (_isVertical && _scrollCtrl.hasClients) {
                    _scrollCtrl.animateTo(
                      page * 800.0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                    );
                  } else if (_pageCtrl.hasClients) {
                    _pageCtrl.animateToPage(
                      page,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
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
              size: 48,
            ),
            const SizedBox(height: 12),
            const Text(
              'Failed to load pages',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchPages,
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

  Widget _buildNoPages() {
    return const Center(
      child: Text(
        'No pages found for this chapter',
        style: TextStyle(color: Colors.white54, fontSize: 15),
      ),
    );
  }
}

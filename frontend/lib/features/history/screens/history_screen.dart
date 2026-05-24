import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../services/history_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _refreshNonce = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _activeType {
    switch (_tabController.index) {
      case 1:
        return 'anime';
      case 2:
        return 'novel';
      default:
        return 'manga';
    }
  }

  Future<void> _clearCurrentType() async {
    final type = _activeType;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text(
          'Clear History',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          'Clear all $type history entries?',
          style: const TextStyle(color: AppTheme.textSecond),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecond),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    await HistoryService.clear(type: type);
    if (mounted) {
      setState(() => _refreshNonce++);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: _clearCurrentType,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecond,
          tabs: const [
            Tab(text: 'Manga'),
            Tab(text: 'Anime'),
            Tab(text: 'Novel'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _HistoryTypeList(type: 'manga', refreshNonce: _refreshNonce),
          _HistoryTypeList(type: 'anime', refreshNonce: _refreshNonce),
          _HistoryTypeList(type: 'novel', refreshNonce: _refreshNonce),
        ],
      ),
    );
  }
}

class _HistoryTypeList extends StatefulWidget {
  final String type;
  final int refreshNonce;

  const _HistoryTypeList({required this.type, required this.refreshNonce});

  @override
  State<_HistoryTypeList> createState() => _HistoryTypeListState();
}

class _HistoryTypeListState extends State<_HistoryTypeList> {
  late Future<List<HistoryEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = HistoryService.getAll(widget.type);
  }

  @override
  void didUpdateWidget(covariant _HistoryTypeList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshNonce != widget.refreshNonce) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _future = HistoryService.getAll(widget.type);
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<HistoryEntry>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          );
        }

        if (snapshot.hasError) {
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
                  const SizedBox(height: 10),
                  Text(
                    snapshot.error.toString(),
                    style: const TextStyle(color: AppTheme.textSecond),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final entries = snapshot.data ?? [];
        if (entries.isEmpty) {
          return _EmptyHistory(type: widget.type);
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          color: AppTheme.primary,
          backgroundColor: AppTheme.card,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return Dismissible(
                key: ValueKey('${entry.sourceId}:${entry.itemId}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade700,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.white,
                  ),
                ),
                confirmDismiss: (_) async {
                  await HistoryService.clearEntry(
                    entry.sourceId,
                    entry.itemId,
                    type: entry.type,
                  );
                  await _refresh();
                  return true;
                },
                child: _HistoryTile(entry: entry),
              );
            },
          ),
        );
      },
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final HistoryEntry entry;

  const _HistoryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.fromMillisecondsSinceEpoch(entry.timestamp).toLocal();
    final timestampText =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: () => _openFromHistory(context, entry),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _accent(entry.type).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _icon(entry.type),
                color: _accent(entry.type),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    entry.progress,
                    style: const TextStyle(
                      color: AppTheme.textSecond,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timestampText,
                    style: TextStyle(
                      color: AppTheme.textSecond.withOpacity(0.85),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecond),
          ],
        ),
      ),
    );
  }

  Color _accent(String type) {
    switch (type) {
      case 'anime':
        return const Color(0xFF06B6D4);
      case 'novel':
        return const Color(0xFFF59E0B);
      default:
        return AppTheme.primary;
    }
  }

  IconData _icon(String type) {
    switch (type) {
      case 'anime':
        return Icons.play_circle_outline_rounded;
      case 'novel':
        return Icons.chrome_reader_mode_outlined;
      default:
        return Icons.menu_book_outlined;
    }
  }

  void _openFromHistory(BuildContext context, HistoryEntry entry) {
    if (entry.itemId.trim().isEmpty || entry.sourceId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Missing source or item id in this history entry'),
        ),
      );
      return;
    }

    if (entry.type == 'anime') {
      context.push(
        '/anime/detail',
        extra: {
          'source': entry.sourceId,
          'id': entry.itemId,
        },
      );
      return;
    }

    if (entry.type == 'novel') {
      context.push(
        '/novel/detail',
        extra: {
          'source': entry.sourceId,
          'id': entry.itemId,
          'title': entry.title,
          'coverUrl': entry.coverUrl,
        },
      );
      return;
    }

    context.push(
      '/manga/detail',
      extra: {
        'source': entry.sourceId,
        'id': entry.itemId,
      },
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  final String type;

  const _EmptyHistory({required this.type});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_rounded,
            size: 64,
            color: AppTheme.textSecond.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No $type history yet',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your $type activity will appear here',
            style: const TextStyle(color: AppTheme.textSecond, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

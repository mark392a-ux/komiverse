import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

class ExtensionsScreen extends StatefulWidget {
  const ExtensionsScreen({super.key});

  @override
  State<ExtensionsScreen> createState() => _ExtensionsScreenState();
}

class _ExtensionsScreenState extends State<ExtensionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _sources = [];
  bool _isLoading = true;
  String? _error;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchSources();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchSources() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await ApiClient.getSources();
      if (!mounted) return;
      final list =
          (res.data['sources'] as List?)
              ?.map((s) => s as Map<String, dynamic>)
              .toList() ??
          [];
      setState(() {
        _sources = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _filterByType(String type) {
    return _sources.where((s) {
      final matchType = (s['type'] ?? '').toString().toLowerCase() == type;
      final matchSearch =
          _search.isEmpty ||
          (s['name'] ?? '').toString().toLowerCase().contains(
            _search.toLowerCase(),
          );
      return matchType && matchSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        title: const Text(
          'Extensions',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppTheme.textPrimary,
            ),
            onPressed: _fetchSources,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: TextField(
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search sources...',
                    hintStyle: const TextStyle(color: AppTheme.textSecond),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppTheme.textSecond,
                    ),
                    filled: true,
                    fillColor: AppTheme.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.primary,
                labelColor: AppTheme.primary,
                unselectedLabelColor: AppTheme.textSecond,
                indicatorSize: TabBarIndicatorSize.label,
                tabs: const [
                  Tab(text: 'Manga'),
                  Tab(text: 'Anime'),
                  Tab(text: 'Novel'),
                  Tab(text: 'All'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : _error != null
          ? _buildError()
          : TabBarView(
              controller: _tabController,
              children: [
                _SourceList(
                  sources: _filterByType('manga'),
                  accentColor: AppTheme.primary,
                ),
                _SourceList(
                  sources: _filterByType('anime'),
                  accentColor: const Color(0xFF06B6D4),
                ),
                _SourceList(
                  sources: _filterByType('novel'),
                  accentColor: const Color(0xFFF59E0B),
                ),
                _SourceList(
                  sources: _search.isEmpty
                      ? _sources
                      : _sources
                            .where(
                              (s) => (s['name'] ?? '')
                                  .toString()
                                  .toLowerCase()
                                  .contains(_search.toLowerCase()),
                            )
                            .toList(),
                  accentColor: AppTheme.accent,
                ),
              ],
            ),
    );
  }

  Widget _buildError() {
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
          const Text(
            'Cannot reach backend',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 17,
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
          ElevatedButton.icon(
            onPressed: _fetchSources,
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
    );
  }
}

// ── Source List ───────────────────────────────────────────────────────────
class _SourceList extends StatelessWidget {
  final List<Map<String, dynamic>> sources;
  final Color accentColor;

  const _SourceList({required this.sources, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    if (sources.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.extension_off_rounded,
              size: 56,
              color: AppTheme.textSecond.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'No sources found',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sources are registered in the backend',
              style: TextStyle(color: AppTheme.textSecond, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
      itemCount: sources.length,
      itemBuilder: (ctx, i) {
        final src = sources[i];
        final type = (src['type'] ?? 'unknown').toString();
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accentColor.withOpacity(0.15)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 6,
            ),
            leading: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accentColor.withOpacity(0.25)),
              ),
              child: Icon(
                type == 'anime'
                    ? Icons.play_circle_outline_rounded
                    : type == 'novel'
                    ? Icons.chrome_reader_mode_outlined
                    : Icons.menu_book_outlined,
                color: accentColor,
                size: 22,
              ),
            ),
            title: Text(
              src['name'] ?? src['id'] ?? '',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  _TypeTag(type: type.toUpperCase(), color: accentColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      src['base_url'] ?? '',
                      style: const TextStyle(
                        color: AppTheme.textSecond,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    color: Colors.green,
                    size: 13,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Active',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TypeTag extends StatelessWidget {
  final String type;
  final Color color;
  const _TypeTag({required this.type, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        type,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

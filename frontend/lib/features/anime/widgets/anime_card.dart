import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../models/anime_model.dart';

class AnimeCard extends StatefulWidget {
  final AnimeModel anime;
  final VoidCallback onTap;

  const AnimeCard({super.key, required this.anime, required this.onTap});

  @override
  State<AnimeCard> createState() => _AnimeCardState();
}

class _AnimeCardState extends State<AnimeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
    );
    _scale = Tween<double>(
      begin: 1,
      end: 0.97,
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
      case 'finished':
        return const Color(0xFF3B82F6);
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
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Cover
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(14),
                ),
                child: Stack(
                  children: [
                    CachedNetworkImage(
                      imageUrl: widget.anime.coverUrl,
                      width: 88,
                      height: 118,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: 88,
                        height: 118,
                        color: AppTheme.surface,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF06B6D4),
                            strokeWidth: 1.5,
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 88,
                        height: 118,
                        color: AppTheme.surface,
                        child: const Icon(
                          Icons.play_circle_outline_rounded,
                          color: AppTheme.textSecond,
                          size: 32,
                        ),
                      ),
                    ),
                    // Play badge
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF06B6D4).withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.anime.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: _statusColor(widget.anime.status),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            widget.anime.status.toUpperCase(),
                            style: TextStyle(
                              color: _statusColor(widget.anime.status),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (widget.anime.totalEpisodes > 0)
                        Row(
                          children: [
                            const Icon(
                              Icons.video_collection_outlined,
                              color: AppTheme.textSecond,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.anime.totalEpisodes} episodes',
                              style: const TextStyle(
                                color: AppTheme.textSecond,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
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
      ),
    );
  }
}

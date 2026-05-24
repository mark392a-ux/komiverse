/// Represents a single anime item from the backend MediaItem shape.
class AnimeModel {
  final String id;
  final String source;
  final String title;
  final String description;
  final String coverUrl;
  final String status;
  final int totalEpisodes;
  final String url;

  AnimeModel({
    required this.id,
    required this.source,
    required this.title,
    required this.description,
    required this.coverUrl,
    required this.status,
    required this.totalEpisodes,
    required this.url,
  });

  factory AnimeModel.fromJson(
    Map<String, dynamic> json, {
    String sourceId = '',
  }) {
    final rawEpisodes = json['total_episodes'] ?? json['episodes'] ?? 0;
    final totalEpisodes = rawEpisodes is num
        ? rawEpisodes.toInt()
        : int.tryParse(rawEpisodes.toString()) ?? 0;

    return AnimeModel(
      id: json['id']?.toString() ?? json['url']?.toString() ?? '',
      source: json['source']?.toString() ?? sourceId,
      title: json['title'] ?? '',
      description: json['description'] ?? json['synopsis'] ?? '',
      coverUrl: json['cover'] ?? json['cover_url'] ?? json['thumbnail'] ?? '',
      status: json['status'] ?? 'ongoing',
      totalEpisodes: totalEpisodes,
      url: json['url'] ?? '',
    );
  }
}

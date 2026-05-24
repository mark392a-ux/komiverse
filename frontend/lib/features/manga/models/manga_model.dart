/// Represents a single manga/webtoon item from the backend MediaItem shape.
class MangaModel {
  final String id; // unique identifier (url or slug)
  final String source; // source ID used for subsequent API calls
  final String title;
  final String description;
  final String coverUrl;
  final String status;
  final String type;
  final String url; // original canonical URL

  MangaModel({
    required this.id,
    required this.source,
    required this.title,
    required this.description,
    required this.coverUrl,
    required this.status,
    required this.type,
    required this.url,
  });

  factory MangaModel.fromJson(
    Map<String, dynamic> json, {
    String sourceId = '',
  }) {
    return MangaModel(
      id: json['id']?.toString() ?? json['url']?.toString() ?? '',
      source: json['source']?.toString() ?? sourceId,
      title: json['title'] ?? '',
      description: json['description'] ?? json['synopsis'] ?? '',
      coverUrl: json['cover'] ?? json['cover_url'] ?? json['thumbnail'] ?? '',
      status: json['status'] ?? 'ongoing',
      type: json['type'] ?? 'manga',
      url: json['url'] ?? '',
    );
  }
}

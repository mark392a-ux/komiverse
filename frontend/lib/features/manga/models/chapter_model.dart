/// Represents a chapter from the backend chapters endpoint.
class ChapterModel {
  final String id; // chapter ID/slug used for pages lookup
  final String source;
  final double number;
  final String title;
  final String url;
  final List<String> pages;

  ChapterModel({
    required this.id,
    required this.source,
    required this.number,
    required this.title,
    required this.url,
    required this.pages,
  });

  factory ChapterModel.fromJson(
    Map<String, dynamic> json, {
    String sourceId = '',
  }) {
    List<String> pageList = [];
    if (json['pages'] is List) {
      pageList = List<String>.from(
        (json['pages'] as List).map((e) => e.toString()),
      );
    } else if (json['images'] is List) {
      pageList = List<String>.from(
        (json['images'] as List).map((e) => e.toString()),
      );
    }
    final rawNum = json['number'] ?? json['chapter'] ?? json['index'] ?? 0;
    double parsedNumber;
    if (rawNum is num) {
      parsedNumber = rawNum.toDouble();
    } else {
      final rawText = rawNum.toString();
      parsedNumber = double.tryParse(rawText) ?? 0;
      if (parsedNumber == 0) {
        final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(rawText);
        if (match != null) {
          parsedNumber = double.tryParse(match.group(1) ?? '') ?? 0;
        }
      }
    }

    return ChapterModel(
      id: json['id']?.toString() ?? json['url']?.toString() ?? '',
      source: json['source']?.toString() ?? sourceId,
      number: parsedNumber,
      title: json['title'] ?? '',
      url: json['url'] ?? '',
      pages: pageList,
    );
  }

  String get displayTitle {
    if (title.isNotEmpty) {
      return title;
    }
    if (number <= 0) {
      return 'Chapter';
    }
    return 'Chapter ${number % 1 == 0 ? number.toInt() : number}';
  }
}

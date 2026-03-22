/// Wrapper phân trang từ Spring Boot server.
/// Tương ứng: PageResponse.java (server)
class PageResponse<T> {
  final List<T> content;
  final int totalPages;
  final int totalElements;
  final int size;
  final int number; // Trang hiện tại (0-based)

  const PageResponse({
    required this.content,
    required this.totalPages,
    required this.totalElements,
    required this.size,
    required this.number,
  });

  factory PageResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    return PageResponse(
      content: (json['content'] as List<dynamic>)
          .map((e) => fromJsonT(e as Map<String, dynamic>))
          .toList(),
      totalPages: json['totalPages'] as int,
      totalElements: json['totalElements'] as int,
      size: json['size'] as int,
      number: json['number'] as int,
    );
  }
}


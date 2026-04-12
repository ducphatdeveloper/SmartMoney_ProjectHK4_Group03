/// Response hiển thị thông tin danh mục.
/// Tương ứng: CategoryResponse.java (server)
class CategoryResponse {
  final int id;
  final String ctgName;
  final bool? ctgType;
  final String? ctgIconUrl;
  final int? parentId;
  final String? parentName; // Tên danh mục cha — server trả về để tránh gọi API thừa

  const CategoryResponse({
    required this.id,
    required this.ctgName,
    this.ctgType,
    this.ctgIconUrl,
    this.parentId,
    this.parentName,
  });

  factory CategoryResponse.fromJson(Map<String, dynamic> json) {
    return CategoryResponse(
      id: json['id'] as int,
      ctgName: json['ctgName'] as String,
      ctgType: json['ctgType'] as bool?,
      ctgIconUrl: json['ctgIconUrl'] as String?,
      parentId: json['parentId'] as int?,
      parentName: json['parentName'] as String?,
    );
  }
}




/// Request tạo/sửa danh mục gửi lên server.
/// Tương ứng: CategoryRequest.java (server)
class CategoryRequest {
  final String ctgName;
  final bool ctgType;
  final String? ctgIconUrl;
  final int? parentId;

  const CategoryRequest({
    required this.ctgName,
    required this.ctgType,
    this.ctgIconUrl,
    this.parentId,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'ctgName': ctgName,
      'ctgType': ctgType,
    };
    if (ctgIconUrl != null) map['ctgIconUrl'] = ctgIconUrl;
    if (parentId != null) map['parentId'] = parentId;
    return map;
  }
}


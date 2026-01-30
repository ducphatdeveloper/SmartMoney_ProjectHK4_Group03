class CategoryModel {
  final int id;
  final String ctgName;
  final bool ctgType; // true: Thu nhập, false: Chi tiêu
  final String? ctgIconUrl;
  final int? parentId;

  CategoryModel({
    required this.id,
    required this.ctgName,
    required this.ctgType,
    this.ctgIconUrl,
    this.parentId,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'],
      ctgName: json['ctgName'],
      ctgType: json['ctgType'],
      ctgIconUrl: json['ctgIconUrl'],
      parentId: json['parentId'],
    );
  }

  // --- HÀM SẮP XẾP CHUẨN TIẾNG VIỆT (A -> Ă -> Â -> B) ---
  static List<CategoryModel> sortCategories(List<CategoryModel> inputList) {
    if (inputList.isEmpty) return [];

    final Map<int, CategoryModel> idMap = {for (var item in inputList) item.id: item};
    final List<CategoryModel> roots = [];
    final Map<int, List<CategoryModel>> childrenMap = {};

    for (var item in inputList) {
      if (item.parentId != null && idMap.containsKey(item.parentId)) {
        childrenMap.putIfAbsent(item.parentId!, () => []).add(item);
      } else {
        roots.add(item);
      }
    }

    // Sắp xếp Roots bằng hàm so sánh tiếng Việt
    roots.sort((a, b) => _compareVietnamese(a.ctgName, b.ctgName));

    final List<CategoryModel> result = [];

    for (var root in roots) {
      result.add(root);

      if (childrenMap.containsKey(root.id)) {
        final myChildren = childrenMap[root.id]!;
        // Sắp xếp Children cũng bằng hàm tiếng Việt
        myChildren.sort((a, b) => _compareVietnamese(a.ctgName, b.ctgName));
        result.addAll(myChildren);
      }
    }

    return result;
  }

  // --- HÀM HỖ TRỢ SO SÁNH TIẾNG VIỆT ---
  static int _compareVietnamese(String s1, String s2) {
    // Chuyển về chữ thường và bỏ dấu để so sánh
    String noSign1 = _removeDiacritics(s1.toLowerCase());
    String noSign2 = _removeDiacritics(s2.toLowerCase());

    int result = noSign1.compareTo(noSign2);

    // Nếu bỏ dấu xong mà giống hệt nhau (VD: "Mây" vs "May"), thì so sánh chuỗi gốc
    if (result == 0) {
      return s1.compareTo(s2);
    }
    return result;
  }

  // Hàm bỏ dấu tiếng Việt thủ công (Nhẹ, không cần thư viện)
  static String _removeDiacritics(String str) {
    var withDiacritics = 'áàảãạăắằẳẵặâấầẩẫậéèẻẽẹêếềểễệíìỉĩịóòỏõọôốồổỗộơớờởỡợúùủũụưứừửữựýỳỷỹỵđ';
    var withoutDiacritics = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';

    for (int i = 0; i < withDiacritics.length; i++) {
      str = str.replaceAll(withDiacritics[i], withoutDiacritics[i]);
    }
    return str;
  }
}
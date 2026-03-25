/// DTO chứa thông tin icon từ server.
/// Tương ứng: IconDTO.java (server) — GET /api/icons
/// fileName: tên file lưu trong database (VD: "icon_food.png")
/// url: URL đầy đủ Cloudinary để hiển thị (VD: "https://res.cloudinary.com/.../icon_food.png")
class IconDto {
  final String fileName; // tên file lưu vào DB khi tạo/sửa category
  final String url;      // URL đầy đủ để hiển thị ảnh

  const IconDto({
    required this.fileName,
    required this.url,
  });

  factory IconDto.fromJson(Map<String, dynamic> json) {
    return IconDto(
      fileName: json['fileName'] as String,
      url: json['url'] as String,
    );
  }
}


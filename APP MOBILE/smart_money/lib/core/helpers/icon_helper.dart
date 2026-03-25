// core/helpers/icon_helper.dart
// Chuyển tên file icon trong database thành URL đầy đủ Cloudinary
// Category / Wallet / SavingGoal đều lưu tên file "icon_food.png" → nối base Cloudinary
//
// Quy tắc:
//   • Category / Wallet / SavingGoal: DB lưu tên file "icon_food.png" → nối base Cloudinary
//   • Nếu null hoặc rỗng → trả null để widget hiện fallback icon

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class IconHelper {

  // Base URL Cloudinary — thay bằng URL thật của project
  // Format: https://res.cloudinary.com/{cloud_name}/image/upload/{transformations}/{public_id}
  static const String _cloudinaryBase =
      'https://res.cloudinary.com/drd2hsocc/image/upload/f_auto,q_auto';

  // =============================================
  // [1] Chuyển tên file → URL Cloudinary đầy đủ
  // =============================================
  // VD: "icon_food.png" → "https://res.cloudinary.com/.../icon_food.png"
  // VD: null → null
  // VD: "https://..." → giữ nguyên (phòng trường hợp backend trả URL đầy đủ)
  static String? buildCloudinaryUrl(String? iconName) {
    if (iconName == null || iconName.trim().isEmpty) return null;

    // Nếu đã là URL đầy đủ → giữ nguyên
    if (iconName.startsWith('http')) return iconName;

    // Nối tên file với base Cloudinary
    return '$_cloudinaryBase/$iconName';
  }

  // Alias cho backward compatibility
  static String? getCategoryIconUrl(String? iconName) => buildCloudinaryUrl(iconName);
  static String? getSourceIconUrl(String? iconUrl) => buildCloudinaryUrl(iconUrl);

  // =============================================
  // [2] Widget: Hiện icon từ URL (Cloudinary)
  // =============================================
  // Dùng CachedNetworkImage — cache ảnh vào bộ nhớ máy
  // Hỗ trợ PNG, JPG, WebP (Cloudinary trả f_auto)
  // Nếu URL null → hiện fallback icon
  static Widget buildNetworkIcon({
    required String? imageUrl,
    required double size,
    Widget? placeholder,
    Widget? errorWidget,
    BoxFit fit = BoxFit.cover,
  }) {
    final fallback = placeholder ?? _defaultPlaceholder(size);

    if (imageUrl == null || imageUrl.trim().isEmpty) return fallback;

    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: size,
      height: size,
      fit: fit,
      placeholder: (_, __) => fallback,
      errorWidget: (_, __, ___) => errorWidget ?? fallback,
    );
  }

  // =============================================
  // [3] Widget: Icon category (tên file → Cloudinary → CachedNetworkImage)
  // =============================================
  // VD: buildCategoryIcon("icon_food.png", size: 40)
  //   → CachedNetworkImage(url: "https://res.cloudinary.com/.../icon_food.png")
  static Widget buildCategoryIcon({
    required String? iconName,
    required double size,
    Widget? placeholder,
  }) {
    final url = buildCloudinaryUrl(iconName);
    return buildNetworkIcon(
      imageUrl: url,
      size: size,
      placeholder: placeholder,
    );
  }

  // =============================================
  // [4] Widget: Icon ví hoặc mục tiêu tiết kiệm
  // =============================================
  static Widget buildWalletIcon({
    required String? iconUrl,
    required double size,
    Widget? placeholder,
  }) {
    return buildNetworkIcon(
      imageUrl: buildCloudinaryUrl(iconUrl),
      size: size,
      placeholder: placeholder,
    );
  }

  static Widget buildSavingGoalIcon({
    required String? iconUrl,
    required double size,
    Widget? placeholder,
  }) {
    return buildNetworkIcon(
      imageUrl: buildCloudinaryUrl(iconUrl),
      size: size,
      placeholder: placeholder,
    );
  }

  // =============================================
  // [5] Widget: Avatar tròn với icon (dùng cho category, wallet, saving goal)
  // =============================================
  static Widget buildCircleAvatar({
    required String? iconUrl,
    required double radius,
    Color? backgroundColor,
    Widget? placeholder,
  }) {
    final size = radius * 2;
    final url = buildCloudinaryUrl(iconUrl);

    if (url == null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor ?? Colors.grey.shade800,
        child: Icon(Icons.category, color: Colors.grey, size: radius),
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      imageBuilder: (context, imageProvider) {
        return CircleAvatar(
          radius: radius,
          backgroundImage: imageProvider,
        );
      },
      placeholder: (_, __) => CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor ?? Colors.grey.shade800,
        child: Icon(Icons.category, color: Colors.grey, size: radius * 0.6),
      ),
      errorWidget: (_, __, ___) => CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor ?? Colors.grey.shade800,
        child: Icon(Icons.category, color: Colors.grey, size: radius * 0.6),
      ),
    );
  }

  // Placeholder mặc định: icon xám trên nền tối
  static Widget _defaultPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(size / 5),
      ),
      child: Icon(Icons.category, color: Colors.grey, size: size * 0.5),
    );
  }
}

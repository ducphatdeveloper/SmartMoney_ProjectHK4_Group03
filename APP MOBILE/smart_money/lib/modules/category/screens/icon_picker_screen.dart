// ===========================================================
// [7] Màn hình chọn Icon (IconPickerScreen)
// ===========================================================
// Hiện khi: User bấm vào icon trong màn Tạo/Sửa danh mục
// API: GET /api/icons → List<IconDto>
// Return: IconDto đã chọn (Navigator.pop)
//
// Layout:
//   • AppBar: "Chọn icon" + nút back
//   • GridView hiển thị tất cả icon từ server
//   • Loading spinner khi đang tải
//   • Error state nếu tải thất bại
// ===========================================================

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:smart_money/modules/category/models/icon_dto.dart';
import 'package:smart_money/modules/category/services/category_service.dart';

class IconPickerScreen extends StatefulWidget {
  /// Icon đang chọn hiện tại (highlight)
  final String? currentIconFileName;

  const IconPickerScreen({super.key, this.currentIconFileName});

  @override
  State<IconPickerScreen> createState() => _IconPickerScreenState();
}

class _IconPickerScreenState extends State<IconPickerScreen> {

  // =============================================
  // [7.1] STATE
  // =============================================
  List<IconDto> _icons = [];      // danh sách icon từ server
  bool _isLoading = true;         // đang tải
  String? _errorMessage;          // lỗi nếu có

  // =============================================
  // [7.2] initState — gọi API lấy danh sách icon
  // =============================================
  @override
  void initState() {
    super.initState();
    _loadIcons();
  }

  Future<void> _loadIcons() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await CategoryService.getIcons();

    if (!mounted) return;

    if (response.success && response.data != null) {
      setState(() {
        _icons = response.data!;
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = response.message.isNotEmpty
            ? response.message
            : 'Không thể tải danh sách icon';
        _isLoading = false;
      });
    }
  }

  // =============================================
  // [7.3] build — giao diện chính
  // =============================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Chọn icon"),
        backgroundColor: Colors.black,
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Loading
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Error
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadIcons,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    // Empty
    if (_icons.isEmpty) {
      return const Center(
        child: Text(
          'Không có icon nào',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    // Grid view icon
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,        // 5 icon mỗi hàng
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _icons.length,
      itemBuilder: (context, index) {
        final icon = _icons[index];
        // Highlight icon đang chọn
        final isSelected = icon.fileName == widget.currentIconFileName;

        return GestureDetector(
          onTap: () {
            // Trả về IconDto đã chọn → screen cha lưu fileName
            Navigator.pop(context, icon);
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? Colors.green.withValues(alpha: 0.3) : Colors.grey.shade900,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: Colors.green, width: 2)
                  : null,
            ),
            padding: const EdgeInsets.all(8),
            child: CachedNetworkImage(
              imageUrl: icon.url,
              fit: BoxFit.contain,
              placeholder: (_, __) => const Center(
                child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: (_, __, ___) => const Icon(
                Icons.broken_image,
                color: Colors.grey,
                size: 24,
              ),
            ),
          ),
        );
      },
    );
  }
}


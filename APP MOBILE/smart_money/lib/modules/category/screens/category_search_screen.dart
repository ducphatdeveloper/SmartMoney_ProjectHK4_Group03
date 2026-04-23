// ===========================================================
// [7] Màn hình tìm kiếm danh mục (CategorySearchScreen)
// ===========================================================
// Mở từ: icon kính lúp trên AppBar của CategoryListScreen
// Flow:
//   1. User gõ từ khóa → debounce 400ms → gọi GET /api/categories/search?name=...
//   2. Hiển thị kết quả dạng danh sách phẳng (không nhóm cha-con)
//   3. Bấm vào kết quả → mở CategoryEditScreen
//   4. Không gõ gì → hiển thị tất cả danh mục (hệ thống + user)
//
// API: GET /api/categories/search?name={keyword}
// ===========================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_money/modules/category/models/category_response.dart';
import 'package:smart_money/modules/category/providers/category_provider.dart';
import 'category_edit_screen.dart';

class CategorySearchScreen extends StatefulWidget {
  const CategorySearchScreen({super.key});

  @override
  State<CategorySearchScreen> createState() => _CategorySearchScreenState();
}

class _CategorySearchScreenState extends State<CategorySearchScreen> {

  // =============================================
  // [7.1] STATE
  // =============================================

  final _searchController = TextEditingController(); // controller ô tìm kiếm
  Timer? _debounce; // timer debounce — tránh gọi API liên tục khi gõ
  bool _hasEdited = false; // theo dõi nếu có sửa/xóa từ kết quả tìm kiếm

  // =============================================
  // [7.2] initState — load tất cả danh mục khi mở
  // =============================================
  @override
  void initState() {
    super.initState();
    // Load tất cả danh mục khi mở màn hình (keyword = null)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<CategoryProvider>(context, listen: false);
      provider.searchCategories(context, null);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel(); // hủy timer khi rời màn hình
    super.dispose();
  }

  // =============================================
  // [7.3] _onSearchChanged — debounce 400ms khi user gõ
  // =============================================
  void _onSearchChanged(String value) {
    // Bước 1: Hủy timer cũ
    _debounce?.cancel();

    // Bước 2: Đặt timer mới — gọi API sau 400ms nếu không gõ thêm
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final provider = Provider.of<CategoryProvider>(context, listen: false);
      provider.searchCategories(context, value.trim().isEmpty ? null : value.trim());
    });

    // Cập nhật UI để hiện/ẩn nút X
    setState(() {});
  }

  // =============================================
  // [7.4] _clearSearch — xóa từ khóa và reset
  // =============================================
  void _clearSearch() {
    _searchController.clear();
    final provider = Provider.of<CategoryProvider>(context, listen: false);
    provider.searchCategories(context, null); // load lại tất cả
    setState(() {});
  }

  // =============================================
  // [7.5] _navigateToEdit — mở sửa danh mục từ kết quả
  // =============================================
  void _navigateToEdit(CategoryResponse category) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryEditScreen(category: category),
      ),
    );

    // Nếu có thay đổi → reload kết quả tìm kiếm + đánh dấu cần reload list
    if (result == true && mounted) {
      _hasEdited = true;
      final keyword = _searchController.text.trim();
      final provider = Provider.of<CategoryProvider>(context, listen: false);
      provider.searchCategories(context, keyword.isEmpty ? null : keyword);
    }
  }

  // =============================================
  // [7.6] build
  // =============================================
  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Khi quay về list screen: trả result=true nếu có thay đổi
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && _hasEdited) {
          // Không cần Navigator.pop vì PopScope tự pop
          // List screen sẽ nhận result = null, nhưng ta truyền qua khác
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: _buildSearchField(), // ô tìm kiếm trong AppBar
          automaticallyImplyLeading: true,
        ),
        body: Consumer<CategoryProvider>(
          builder: (context, provider, _) {

            // ---- Loading ----
            if (provider.isLoading) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.green),
              );
            }

            // ---- Lỗi ----
            if (provider.errorMessage != null) {
              return Center(
                child: Text(
                  provider.errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }

            final results = provider.searchResults;

            // ---- Không có kết quả ----
            if (results.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.search_off, color: Colors.grey, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      _searchController.text.isEmpty
                          ? "No categories yet"
                          : 'No results for "${_searchController.text}"',
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
              );
            }

            // ---- Danh sách kết quả ----
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: results.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Color(0xFF2C2C2E)),
              itemBuilder: (context, index) {
                return _buildResultItem(results[index]);
              },
            );
          },
        ),
      ),
    );
  }

  // =============================================
  // [7.7] Widget: ô tìm kiếm trong AppBar
  // =============================================
  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      autofocus: true, // focus ngay khi mở
      style: const TextStyle(color: Colors.white),
      cursorColor: Colors.green,
      onChanged: _onSearchChanged,
      decoration: InputDecoration(
        hintText: "Search categories...",
        hintStyle: const TextStyle(color: Colors.grey),
        border: InputBorder.none,
        // Nút X xóa tìm kiếm
        suffixIcon: _searchController.text.isNotEmpty
            ? GestureDetector(
                onTap: _clearSearch,
                child: const Icon(Icons.close, color: Colors.grey),
              )
            : null,
      ),
    );
  }

  // =============================================
  // [7.8] Widget: một item kết quả tìm kiếm
  // =============================================
  Widget _buildResultItem(CategoryResponse category) {
    final isChild = category.parentId != null; // là danh mục con?

    return ListTile(
      onTap: () => _navigateToEdit(category),
      leading: CircleAvatar(
        backgroundColor: Colors.grey.shade800,
        child: const Icon(Icons.category, color: Colors.white, size: 20),
      ),
      title: Text(
        category.ctgName,
        style: const TextStyle(color: Colors.white, fontSize: 15),
      ),
      subtitle: Row(
        children: [
          // Badge: Chi tiêu / Thu nhập
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: (category.ctgType == true)
                  ? Colors.green.withValues(alpha: 0.2)
                  : Colors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              category.ctgType == true ? "Income" : "Expense",
              style: TextStyle(
                color: category.ctgType == true ? Colors.green : Colors.orange,
                fontSize: 11,
              ),
            ),
          ),
          // Badge: "Danh mục con" nếu có parentId
          if (isChild) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                "Subcategory",
                style: TextStyle(color: Colors.blue, fontSize: 11),
              ),
            ),
          ],
        ],
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category_model.dart';
import '../providers/category_provider.dart';

class CategoryListScreen extends StatefulWidget {
  const CategoryListScreen({super.key});

  @override
  State<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends State<CategoryListScreen> {
  @override
  void initState() {
    super.initState();
    // Gọi fetchCategories khi màn hình được khởi tạo
    // Có thể truyền group nếu muốn lọc ngay từ đầu
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CategoryProvider>(context, listen: false).fetchCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Danh mục'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              Provider.of<CategoryProvider>(context, listen: false).fetchCategories();
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // Ví dụ thêm danh mục mới
              _showAddCategoryDialog(context);
            },
          ),
        ],
      ),
      body: Consumer<CategoryProvider>(
        builder: (context, categoryProvider, child) {
          if (categoryProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (categoryProvider.errorMessage != null) {
            return Center(
              child: Text(
                'Lỗi: ${categoryProvider.errorMessage}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          // Hiển thị danh sách các danh mục
          // Bạn có thể dùng TabBarView để chia 3 danh sách (Expense, Income, Debt)
          return ListView(
            children: [
              _buildCategorySection(
                context,
                'Danh mục Chi tiêu',
                categoryProvider.expenseList,
                categoryProvider,
              ),
              _buildCategorySection(
                context,
                'Danh mục Thu nhập',
                categoryProvider.incomeList,
                categoryProvider,
              ),
              _buildCategorySection(
                context,
                'Danh sách Vay/Nợ',
                categoryProvider.debtList,
                categoryProvider,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCategorySection(
    BuildContext context,
    String title,
    List<CategoryModel> categories,
    CategoryProvider provider,
  ) {
    return ExpansionTile(
      title: Text('$title (${categories.length})'),
      children: categories.isEmpty
          ? [const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('Không có danh mục nào.'),
            )]
          : categories.map((category) {
              return ListTile(
                leading: category.ctgIconUrl != null
                    ? CircleAvatar(child: Text(category.ctgIconUrl![0].toUpperCase())) // Thay bằng Icon thực tế
                    : null,
                title: Text(category.ctgName),
                subtitle: Text(category.ctgType ? 'Thu nhập' : 'Chi tiêu'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        _showEditCategoryDialog(context, category, provider);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        _showDeleteConfirmationDialog(context, category, provider);
                      },
                    ),
                  ],
                ),
              );
            }).toList(),
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    bool isIncome = false; // Mặc định là chi tiêu
    int? parentId; // Ví dụ: có thể chọn parentId

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm Danh mục mới'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Tên danh mục'),
            ),
            SwitchListTile(
              title: const Text('Là Thu nhập?'),
              value: isIncome,
              onChanged: (value) {
                setState(() {
                  isIncome = value;
                });
              },
            ),
            // Thêm dropdown chọn parentId nếu cần
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              final newCategory = CategoryModel(
                id: 0, // ID sẽ được backend gán
                ctgName: nameController.text,
                ctgType: isIncome,
                ctgIconUrl: 'icon_default.svg', // Icon mặc định
                parentId: parentId,
              );
              Provider.of<CategoryProvider>(context, listen: false).addCategory(newCategory);
              Navigator.of(ctx).pop();
            },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
  }

  void _showEditCategoryDialog(BuildContext context, CategoryModel category, CategoryProvider provider) {
    final TextEditingController nameController = TextEditingController(text: category.ctgName);
    bool isIncome = category.ctgType;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sửa Danh mục'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Tên danh mục'),
            ),
            SwitchListTile(
              title: const Text('Là Thu nhập?'),
              value: isIncome,
              onChanged: (value) {
                setState(() {
                  isIncome = value;
                });
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              final updatedCategory = category.copyWith(
                ctgName: nameController.text,
                ctgType: isIncome,
              );
              provider.updateCategory(updatedCategory);
              Navigator.of(ctx).pop();
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, CategoryModel category, CategoryProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc chắn muốn xóa danh mục "${category.ctgName}" không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.deleteCategory(category.id);
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

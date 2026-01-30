import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Thư viện quản lý trạng thái (State Management)
import '../models/category_model.dart';
import '../providers/category_provider.dart';

// StatefulWidget: Màn hình có trạng thái thay đổi (ví dụ: loading -> có dữ liệu)
class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {

  // initState: Hàm chạy ĐẦU TIÊN khi màn hình được tạo ra.
  // Giống như ngOnInit trong Angular hay componentDidMount trong React.
  @override
  void initState() {
    super.initState();

    // Gọi API lấy dữ liệu ngay khi mở màn hình.
    // WidgetsBinding...addPostFrameCallback: Đảm bảo giao diện đã vẽ xong khung đầu tiên rồi mới gọi hàm này.
    // Tránh lỗi "setState() called during build" thường gặp.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Provider.of(..., listen: false): Chỉ gọi hàm, KHÔNG lắng nghe thay đổi để vẽ lại UI ở đây.
      Provider.of<CategoryProvider>(context, listen: false).fetchCategories();
    });
  }

  // build: Hàm vẽ giao diện (chạy lại mỗi khi setState hoặc Provider báo thay đổi)
  @override
  Widget build(BuildContext context) {
    // Lắng nghe dữ liệu từ Provider.
    // Khi Provider gọi notifyListeners(), hàm build này sẽ chạy lại để cập nhật UI.
    final provider = Provider.of<CategoryProvider>(context);

    // DefaultTabController: Widget quản lý trạng thái của 3 Tab (Chi, Thu, Nợ)
    return DefaultTabController(
      length: 3, // Số lượng Tab
      child: Scaffold(
        // AppBar: Thanh tiêu đề trên cùng
        appBar: AppBar(
          title: const Text("Danh mục"),
          backgroundColor: Colors.black,
          // TabBar: Thanh chứa các nút Tab
          bottom: const TabBar(
            indicatorColor: Colors.green, // Màu gạch dưới tab đang chọn
            labelColor: Colors.green,     // Màu chữ tab đang chọn
            unselectedLabelColor: Colors.grey, // Màu chữ tab chưa chọn
            tabs: [
              Tab(text: "KHOẢN CHI"),
              Tab(text: "KHOẢN THU"),
              Tab(text: "ĐI VAY & CHO VAY"),
            ],
          ),
        ),

        // Body: Phần nội dung chính
        // Builder: Dùng để tách context nếu cần (ở đây dùng để code gọn hơn)
        body: Builder(
          builder: (context) {
            // TRƯỜNG HỢP 1: Đang tải dữ liệu
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator()); // Vòng xoay loading
            }

            // TRƯỜNG HỢP 2: Có lỗi xảy ra (mất mạng, server sập...)
            if (provider.errorMessage != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center, // Căn giữa dọc
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 48),
                    const SizedBox(height: 16), // Khoảng cách
                    Text("Lỗi: ${provider.errorMessage}", style: const TextStyle(color: Colors.white)),
                    const SizedBox(height: 16),
                    // Nút thử lại
                    ElevatedButton(
                      onPressed: () => provider.fetchCategories(), // Gọi lại API
                      child: const Text("Thử lại"),
                    )
                  ],
                ),
              );
            }

            // TRƯỜNG HỢP 3: Tải xong, hiển thị dữ liệu
            // TabBarView: Nội dung tương ứng với từng Tab
            return TabBarView(
              children: [
                // Tab 1: Danh sách Chi (Lấy từ getter expenseList đã xử lý trong Provider)
                _buildCategoryList(provider.expenseList),

                // Tab 2: Danh sách Thu
                _buildCategoryList(provider.incomeList),

                // Tab 3: Danh sách Vay/Nợ
                _buildCategoryList(provider.debtList),
              ],
            );
          },
        ),
      ),
    );
  }

  // --- Widget tách lẻ để tái sử dụng code hiển thị danh sách ---
  // Nhận vào một List<CategoryModel> và trả về một ListView
  Widget _buildCategoryList(List<CategoryModel> categories) {
    // Nếu danh sách rỗng
    if (categories.isEmpty) {
      return const Center(child: Text("Không có danh mục nào", style: TextStyle(color: Colors.grey)));
    }

    // ListView.builder: Tối ưu hiệu năng, chỉ vẽ những item đang hiển thị trên màn hình
    return ListView.builder(
      itemCount: categories.length, // Tổng số phần tử
      itemBuilder: (context, index) {
        final category = categories[index];

        // Kiểm tra xem mục này có phải là con không (có parentId)
        final isChild = category.parentId != null;

        return Container(
          // Logic thụt đầu dòng: Nếu là con thì thụt vào 40px, cha thì 0
          padding: EdgeInsets.only(left: isChild ? 40.0 : 0),

          // ListTile: Widget chuẩn của Flutter để hiển thị 1 dòng (Icon - Title - Subtitle)
          child: ListTile(
            // Icon bên trái
            leading: CircleAvatar(
              radius: isChild ? 16 : 20, // Con thì icon nhỏ hơn chút
              backgroundColor: Colors.grey[800],
              child: Icon(
                // Logic chọn icon: Thu nhập mũi tên xuống, Chi tiêu mũi tên lên (hoặc ngược lại tùy logic)
                category.ctgType ? Icons.arrow_downward : Icons.arrow_upward,
                color: category.ctgType ? Colors.green : Colors.red,
                size: isChild ? 16 : 24,
              ),
            ),

            // Tên danh mục
            title: Text(
              category.ctgName,
              style: TextStyle(
                color: Colors.white,
                // Cha thì chữ đậm, Con thì chữ thường
                fontWeight: isChild ? FontWeight.normal : FontWeight.bold,
                fontSize: isChild ? 14 : 16,
              ),
            ),

            // Đường kẻ mờ phân cách giữa các dòng
            shape: Border(bottom: BorderSide(color: Colors.grey.shade900, width: 0.5)),
          ),
        );
      },
    );
  }
}
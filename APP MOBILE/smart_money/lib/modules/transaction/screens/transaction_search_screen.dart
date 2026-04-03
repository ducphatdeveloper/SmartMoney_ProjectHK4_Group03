// ===========================================================
// [7] TransactionSearchScreen — Màn hình tìm kiếm giao dịch
// ===========================================================
// Trách nhiệm:
//   • Cho user nhập từ khóa tìm kiếm (ghi chú, người giao dịch)
//   • Hiển thị bộ lọc nâng cao LUÔN HIỆN (không ẩn sau button)
//     → Dễ hiểu hơn khi thầy cô hỏi, team dễ sửa hơn
//   • Gọi POST /api/transactions/search khi user bấm TÌM KIẾM
//   • Hiển thị kết quả dưới dạng danh sách phẳng (không nhóm)
//
// Layout:
//   • AppBar: nút X đóng + tiêu đề "Tìm kiếm" + nút TÌM KIẾM
//   • Phần bộ lọc (luôn hiện, cuộn được):
//       [A] Ghi chú — TextField tìm trong note
//       [B] Với ai  — TextField tìm trong withPerson
//       [C] Số tiền — SegmentedButton: Tất cả | Lớn hơn | Nhỏ hơn | Trong khoảng
//       [D] Ví      — DropdownButton: Tất cả | từng ví | từng goal
//       [E] Thời gian — SegmentedButton: Tất cả | Tháng này | Tháng trước | Tùy chọn
//       [F] Nhóm    — bấm → mở CategoryListScreen ở chế độ chọn
//   • Phần kết quả: hiện sau khi bấm TÌM KIẾM
//       Empty state nếu chưa tìm
//       Loading nếu đang gọi API
//       List nếu có kết quả
//       "0 kết quả" nếu không tìm thấy
//
// Flow:
//   1. User mở màn → load danh sách ví để hiện dropdown
//   2. User nhập bộ lọc (ghi chú, ví, thời gian, nhóm...)
//   3. Bấm "TÌM KIẾM" → validate → gọi API search
//   4. Hiện kết quả bên dưới bộ lọc
//   5. Bấm vào giao dịch → mở TransactionDetailSheet
//
// API: POST /api/transactions/search
// Body: TransactionSearchRequest { note, withPerson, walletId,
//       savingGoalId, categoryId, startDate, endDate }
//
// Lỗi server có thể trả:
//   • Không có lỗi đặc biệt — search chỉ trả list rỗng nếu không thấy
// ===========================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:smart_money/core/helpers/format_helper.dart';
import 'package:smart_money/core/helpers/icon_helper.dart';
import 'package:smart_money/modules/transaction/models/request/transaction_search_request.dart';
import 'package:smart_money/modules/transaction/models/view/transaction_response.dart';
import 'package:smart_money/modules/transaction/services/transaction_service.dart';
import 'package:smart_money/modules/transaction/services/util_service.dart';
import 'package:smart_money/modules/transaction/widgets/transaction_detail_sheet.dart';
import 'package:smart_money/modules/transaction/screens/transaction_edit_screen.dart';
import 'package:smart_money/modules/transaction/providers/transaction_provider.dart';
import 'package:smart_money/modules/category/models/category_response.dart';
import 'package:smart_money/modules/category/screens/category_list_screen.dart';
import 'package:smart_money/modules/wallet/models/wallet_response.dart';
import 'package:smart_money/modules/saving_goal/models/saving_goal_response.dart';

class TransactionSearchScreen extends StatefulWidget {
  const TransactionSearchScreen({super.key});

  @override
  State<TransactionSearchScreen> createState() => _TransactionSearchScreenState();
}

class _TransactionSearchScreenState extends State<TransactionSearchScreen> {

  // =============================================
  // [7.1] STATE — Bộ lọc + kết quả
  // =============================================

  // --- Controllers ---
  final _noteController       = TextEditingController(); // ô nhập ghi chú
  final _withPersonController = TextEditingController(); // ô nhập "với ai"
  final _minAmountController  = TextEditingController(); // ô nhập số tiền nhỏ nhất
  final _maxAmountController  = TextEditingController(); // ô nhập số tiền lớn nhất

  // --- Bộ lọc số tiền ---
  // 'all' = Tất cả | 'gt' = Lớn hơn | 'lt' = Nhỏ hơn | 'range' = Trong khoảng
  String _amountFilter = 'all';

  // --- Bộ lọc ví ---
  // null = không lọc theo ví nào cả (Tất cả)
  WalletResponse? _selectedWallet;          // ví thường đã chọn
  SavingGoalResponse? _selectedGoal;        // mục tiêu tiết kiệm đã chọn

  // --- Bộ lọc thời gian ---
  // 'all' = Tất cả | 'this_month' | 'last_month' | 'custom'
  String _timeFilter = 'all';
  DateTime? _customStartDate; // chỉ dùng khi _timeFilter = 'custom'
  DateTime? _customEndDate;

  // --- Bộ lọc nhóm (category) ---
  CategoryResponse? _selectedCategory; // null = tất cả nhóm

  // --- Danh sách dropdown (load từ API khi mở màn hình) ---
  List<WalletResponse>    _wallets = [];  // danh sách ví
  List<SavingGoalResponse> _goals  = [];  // danh sách mục tiêu tiết kiệm
  bool _loadingDropdowns = false;          // đang load danh sách ví/goal

  // --- Kết quả tìm kiếm ---
  List<TransactionResponse> _results = [];      // danh sách kết quả
  bool _isSearching = false;                    // đang gọi API tìm kiếm
  bool _hasSearched = false;                    // đã tìm ít nhất 1 lần chưa
  String? _searchError;                         // lỗi tìm kiếm (nếu có)

  // =============================================
  // [7.2] initState — Load danh sách ví khi mở màn hình
  // =============================================
  @override
  void initState() {
    super.initState();
    // Dùng addPostFrameCallback để tránh gọi setState trong build
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDropdownData());
  }

  // =============================================
  // [7.3] dispose — Giải phóng controller tránh memory leak
  // =============================================
  @override
  void dispose() {
    _noteController.dispose();
    _withPersonController.dispose();
    _minAmountController.dispose();
    _maxAmountController.dispose();
    super.dispose();
  }

  // =============================================
  // [7.4] _loadDropdownData — Load ví + goal cho dropdown
  // =============================================
  // Gọi khi: mở màn hình lần đầu
  // API: GET /user/wallets + GET /saving-goals/getAll (qua UtilService)
  Future<void> _loadDropdownData() async {
    setState(() => _loadingDropdowns = true);

    // Bước 1: Gọi song song 2 API để tiết kiệm thời gian
    final results = await Future.wait([
      UtilService.getAllWallets(),
      UtilService.getAllSavingGoals(),
    ]);

    // Bước 2: Gán kết quả
    final walletRes = results[0] as dynamic;
    final goalRes   = results[1] as dynamic;

    setState(() {
      // Gán ví nếu thành công
      if (walletRes.success && walletRes.data != null) {
        _wallets = walletRes.data as List<WalletResponse>;
      }
      // Gán goal nếu thành công
      if (goalRes.success && goalRes.data != null) {
        _goals = goalRes.data as List<SavingGoalResponse>;
      }
      _loadingDropdowns = false;
    });
  }

  // =============================================
  // [7.5] _openCategoryPicker — Mở màn hình chọn nhóm
  // =============================================
  // Tái sử dụng CategoryListScreen với isSelectMode=true
  // → Bấm vào category → trả về CategoryResponse thay vì mở EditScreen
  Future<void> _openCategoryPicker() async {
    final result = await Navigator.push<CategoryResponse>(
      context,
      MaterialPageRoute(
        builder: (_) => const CategoryListScreen(
          isSelectMode: true,  // chế độ chọn nhóm cho transaction
          initialTab: 'expense', // mặc định tab Chi tiêu
        ),
      ),
    );

    // Nếu user chọn một danh mục → cập nhật state
    if (result != null) {
      setState(() => _selectedCategory = result);
    }
  }

  // =============================================
  // [7.6] _openDateRangePicker — Mở dialog chọn ngày tùy chỉnh
  // =============================================
  Future<void> _openDateRangePicker() async {
    // Bước 1: Mở DateRangePicker của Flutter
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),       // giới hạn ngày sớm nhất
      lastDate: DateTime(2030),        // giới hạn ngày muộn nhất
      initialDateRange: (_customStartDate != null && _customEndDate != null)
          ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
          : null,
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: Colors.green),
        ),
        child: child!,
      ),
    );

    // Bước 2: Gán kết quả nếu user chọn xong (không bấm hủy)
    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate   = picked.end;
        _timeFilter      = 'custom'; // tự chuyển sang custom
      });
    }
  }

  // =============================================
  // [7.7] _buildSearchRequest — Tạo request body từ bộ lọc hiện tại
  // =============================================
  // Gọi khi: user bấm TÌM KIẾM
  // Trả về: TransactionSearchRequest để gửi lên server
  TransactionSearchRequest _buildSearchRequest() {
    // Bước 1: Tính startDate / endDate dựa theo bộ lọc thời gian
    DateTime? startDate;
    DateTime? endDate;

    final now = DateTime.now();
    switch (_timeFilter) {
      case 'this_month':
        // Từ ngày 1 đến cuối tháng hiện tại
        startDate = DateTime(now.year, now.month, 1);
        endDate   = DateTime(now.year, now.month + 1, 1)
                        .subtract(const Duration(seconds: 1));
        break;
      case 'last_month':
        // Từ ngày 1 đến cuối tháng trước
        startDate = DateTime(now.year, now.month - 1, 1);
        endDate   = DateTime(now.year, now.month, 1)
                        .subtract(const Duration(seconds: 1));
        break;
      case 'custom':
        // User tự chọn ngày
        startDate = _customStartDate;
        endDate   = _customEndDate;
        break;
      // 'all': không set startDate/endDate → server lấy tất cả
    }

    // Bước 2: Tính minAmount / maxAmount từ bộ lọc số tiền
    double? minAmount;
    double? maxAmount;

    switch (_amountFilter) {
      case 'gt': // Lớn hơn X
        minAmount = double.tryParse(_minAmountController.text.replaceAll(',', ''));
        break;
      case 'lt': // Nhỏ hơn X
        maxAmount = double.tryParse(_minAmountController.text.replaceAll(',', ''));
        break;
      case 'range': // Trong khoảng X → Y
        minAmount = double.tryParse(_minAmountController.text.replaceAll(',', ''));
        maxAmount = double.tryParse(_maxAmountController.text.replaceAll(',', ''));
        break;
    }

    // Bước 3: Tạo request — chỉ gán field nếu có giá trị
    return TransactionSearchRequest(
      note:         _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      withPerson:   _withPersonController.text.trim().isEmpty ? null : _withPersonController.text.trim(),
      walletId:     _selectedWallet?.id,         // null nếu chọn Tất cả hoặc đang chọn goal
      savingGoalId: _selectedGoal?.id,           // null nếu chọn Tất cả hoặc đang chọn ví
      // TransactionSearchRequest mong đợi một danh sách ID danh mục (categoryIds)
      // Giao diện hiện tại chỉ cho chọn 1 danh mục nên ta đóng gói thành danh sách 1 phần tử
      categoryIds:  _selectedCategory != null ? [_selectedCategory!.id] : null,
      startDate:    startDate,
      endDate:      endDate,
      minAmount:    minAmount,
      maxAmount:    maxAmount,
    );
  }

  // =============================================
  // [7.8] _search — Gọi API tìm kiếm
  // =============================================
  // Gọi khi: user bấm "TÌM KIẾM" trên AppBar
  Future<void> _search() async {
    // Bước 1: Đóng bàn phím nếu đang mở
    FocusScope.of(context).unfocus();

    // Bước 2: Bật trạng thái đang tìm
    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _searchError = null;
    });

    // Bước 3: Build request và gọi API
    final request = _buildSearchRequest();
    final response = await TransactionService.search(request);

    // Bước 4: Kiểm tra mounted tránh crash sau async
    if (!mounted) return;

    // Bước 5: Xử lý kết quả
    setState(() {
      _isSearching = false;
      if (response.success && response.data != null) {
        _results = response.data!;      // gán kết quả mới
        _searchError = null;
      } else {
        _results = [];
        _searchError = response.message; // lỗi server (hiếm với search)
      }
    });
  }

  // =============================================
  // [7.9] _resetFilters — Reset toàn bộ bộ lọc về mặc định
  // =============================================
  void _resetFilters() {
    setState(() {
      _noteController.clear();
      _withPersonController.clear();
      _minAmountController.clear();
      _maxAmountController.clear();
      _amountFilter    = 'all';
      _selectedWallet  = null;
      _selectedGoal    = null;
      _timeFilter      = 'all';
      _customStartDate = null;
      _customEndDate   = null;
      _selectedCategory = null;
      _results         = [];
      _hasSearched     = false;
      _searchError     = null;
    });
  }

  // =============================================
  // [7.10] build — Giao diện chính
  // =============================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(),
      body: CustomScrollView(
        slivers: [
          // Phần bộ lọc (fixed at top)
          SliverToBoxAdapter(
            child: _buildFilterSection(),
          ),
          const SliverToBoxAdapter(child: Divider(color: Color(0xFF2C2C2E), height: 1)),
          // Phần kết quả (scrollable)
          SliverToBoxAdapter(child: _buildResultSection()),
        ],
      ),
    );
  }

  // =============================================
  // [7.10a] Widget: AppBar
  // =============================================
  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.black,
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: () => Navigator.pop(context), // đóng màn hình
      ),
      title: const Text("Tìm kiếm", style: TextStyle(color: Colors.white)),
      actions: [
        // Nút TÌM KIẾM — chỉ enable khi không đang search
        TextButton(
          onPressed: _isSearching ? null : _search,
          child: Text(
            "TÌM KIẾM",
            style: TextStyle(
              color: _isSearching ? Colors.grey : Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // =============================================
  // [7.10b] Widget: Toàn bộ phần bộ lọc
  // =============================================
  Widget _buildFilterSection() {
    return Container(
      color: const Color(0xFF1C1C1E),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // [A] Ghi chú
          _buildFilterRow(
            label: "GHI CHÚ",
            child: TextField(
              controller: _noteController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Ghi chú",
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none,
              ),
            ),
          ),

          _filterDivider(),

          // [B] Với ai
          _buildFilterRow(
            label: "VỚI",
            child: TextField(
              controller: _withPersonController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Với",
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none,
              ),
            ),
          ),

          _filterDivider(),

          // [C] Số tiền
          _buildAmountFilter(),

          _filterDivider(),

          // [D] Ví / Mục tiêu
          _buildWalletFilter(),

          _filterDivider(),

          // [E] Thời gian
          _buildTimeFilter(),

          _filterDivider(),

          // [F] Nhóm (Category)
          _buildCategoryFilter(),

          // Nút Reset bộ lọc
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _resetFilters,
            icon: const Icon(Icons.refresh, size: 16, color: Colors.grey),
            label: const Text("Xóa bộ lọc", style: TextStyle(color: Colors.grey, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // =============================================
  // [7.10c] Widget: Bộ lọc số tiền
  // =============================================
  Widget _buildAmountFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label + 4 nút chọn kiểu lọc
        _buildFilterLabel("SỐ TIỀN"),
        const SizedBox(height: 8),
        // 4 chip chọn kiểu lọc số tiền
        Wrap(
          spacing: 8,
          children: [
            _buildChip(label: "Tất cả",      value: "all"),
            _buildChip(label: "Lớn hơn",     value: "gt"),
            _buildChip(label: "Nhỏ hơn",     value: "lt"),
            _buildChip(label: "Trong khoảng", value: "range"),
          ],
        ),
        // Hiện ô nhập số tiền khi không phải "Tất cả"
        if (_amountFilter != 'all') ...[
          const SizedBox(height: 8),
          Row(
            children: [
              // Ô nhập số tiền tối thiểu (dùng cho gt, lt, range)
              Expanded(
                child: TextField(
                  controller: _minAmountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: _amountFilter == 'lt' ? "Nhỏ hơn..." : "Từ...",
                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFF2C2C2E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              // Chỉ hiện ô thứ 2 khi chọn "Trong khoảng"
              if (_amountFilter == 'range') ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text("→", style: TextStyle(color: Colors.grey)),
                ),
                Expanded(
                  child: TextField(
                    controller: _maxAmountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Đến...",
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFF2C2C2E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  // =============================================
  // [7.10d] Widget: Bộ lọc ví / mục tiêu
  // =============================================
  // [FIX] Đổi từ DropdownButton → GestureDetector + showModalBottomSheet
  // Vì DropdownButton không hỗ trợ tốt CachedNetworkImage trong DropdownMenuItem
  // → Giờ dùng bottom sheet như transaction_app_bar.dart và create/edit screen
  Widget _buildWalletFilter() {
    // Xác định tên + iconUrl đang chọn để hiện trên row
    String currentLabel = 'Tất cả các ví';
    String? currentIconUrl;
    String currentType = 'all'; // 'all' | 'wallet' | 'saving_goal'

    if (_selectedWallet != null) {
      currentLabel = _selectedWallet!.walletName;
      currentIconUrl = _selectedWallet!.goalImageUrl; // WalletResponse.goalImageUrl
      currentType = 'wallet';
    } else if (_selectedGoal != null) {
      currentLabel = _selectedGoal!.goalName;
      currentIconUrl = _selectedGoal!.imageUrl; // SavingGoalResponse.imageUrl
      currentType = 'saving_goal';
    }

    return _buildFilterRow(
      label: "VÍ",
      child: _loadingDropdowns
          // Đang load → hiện spinner nhỏ
          ? const SizedBox(
              height: 20, width: 20,
              child: CircularProgressIndicator(color: Colors.green, strokeWidth: 2),
            )
          // Đã load → hiện row bấm mở sheet
          : GestureDetector(
              onTap: _showWalletBottomSheet, // bấm → mở bottom sheet chọn ví
              child: Row(
                children: [
                  // Icon ví hiện tại: Cloudinary nếu có, fallback nếu không
                  _buildWalletRowIcon(currentIconUrl, currentType),
                  const SizedBox(width: 10),
                  // Tên ví hiện tại
                  Expanded(
                    child: Text(
                      currentLabel,
                      style: TextStyle(
                        color: (_selectedWallet != null || _selectedGoal != null)
                            ? Colors.white
                            : Colors.grey,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Nút X xóa chọn ví (chỉ hiện khi đang chọn ví cụ thể)
                  if (_selectedWallet != null || _selectedGoal != null)
                    GestureDetector(
                      onTap: () => setState(() {
                        _selectedWallet = null;
                        _selectedGoal = null;
                      }),
                      child: const Icon(Icons.close, color: Colors.grey, size: 18),
                    )
                  else
                    const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
                ],
              ),
            ),
    );
  }

  // =============================================
  // [7.10d-1] _buildWalletRowIcon — icon nhỏ hiển thị trên row
  // =============================================
  // Dùng CachedNetworkImage qua IconHelper, fallback icon Material
  Widget _buildWalletRowIcon(String? iconUrl, String type) {
    final url = IconHelper.buildCloudinaryUrl(iconUrl);
    if (url != null) {
      return CachedNetworkImage(
        imageUrl: url,
        width: 32,
        height: 32,
        imageBuilder: (context, imageProvider) => Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
          ),
        ),
        placeholder: (_, __) => _buildWalletFallbackIcon(type, 32),
        errorWidget: (_, __, ___) => _buildWalletFallbackIcon(type, 32),
      );
    }
    return _buildWalletFallbackIcon(type, 32);
  }

  // =============================================
  // [7.10d-2] _buildWalletFallbackIcon — icon mặc định khi không có URL
  // =============================================
  Widget _buildWalletFallbackIcon(String type, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: type == 'saving_goal'
            ? Colors.orange.shade400
            : (type == 'wallet' ? Colors.green.shade400 : Colors.grey.shade700),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        type == 'saving_goal'
            ? Icons.savings
            : (type == 'wallet'
                ? Icons.account_balance_wallet
                : Icons.wallet_giftcard),
        color: Colors.white,
        size: size * 0.55,
      ),
    );
  }

  // =============================================
  // [7.10d-3] _showWalletBottomSheet — bottom sheet chọn ví/goal
  // =============================================
  // Pattern giống transaction_app_bar.dart và transaction_create_screen.dart
  void _showWalletBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Tiêu đề sheet
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Chọn ví',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const Divider(color: Color(0xFF2C2C2E), height: 1),
            // Danh sách: Tất cả + wallets + goals
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  // --- Tất cả các ví ---
                  ListTile(
                    leading: _buildWalletFallbackIcon('all', 40),
                    title: const Text('Tất cả các ví', style: TextStyle(color: Colors.white)),
                    trailing: (_selectedWallet == null && _selectedGoal == null)
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedWallet = null;
                        _selectedGoal = null;
                      });
                      Navigator.pop(ctx);
                    },
                  ),
                  // --- Danh sách ví thường ---
                  if (_wallets.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text('VÍ CÁ NHÂN', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    ),
                    ..._wallets.map((w) {
                      final isSelected = _selectedWallet?.id == w.id;
                      return ListTile(
                        leading: _buildWalletRowIcon(w.goalImageUrl, 'wallet'),
                        title: Text(
                          w.walletName,
                          style: TextStyle(
                            color: isSelected ? Colors.green : Colors.white,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          FormatHelper.formatVND(w.balance),
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedWallet = w;
                            _selectedGoal = null;
                          });
                          Navigator.pop(ctx);
                        },
                      );
                    }),
                  ],
                  // --- Danh sách mục tiêu tiết kiệm ---
                  if (_goals.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text('MỤC TIÊU TIẾT KIỆM', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    ),
                    ..._goals.map((g) {
                      final isSelected = _selectedGoal?.id == g.id;
                      return ListTile(
                        leading: _buildWalletRowIcon(g.imageUrl, 'saving_goal'),
                        title: Text(
                          g.goalName,
                          style: TextStyle(
                            color: isSelected ? Colors.green : Colors.white,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          FormatHelper.formatVND(g.currentAmount),
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedGoal = g;
                            _selectedWallet = null;
                          });
                          Navigator.pop(ctx);
                        },
                      );
                    }),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // =============================================
  // [7.10e] Widget: Bộ lọc thời gian
  // =============================================
  Widget _buildTimeFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFilterLabel("THỜI GIAN"),
        const SizedBox(height: 8),
        // 4 chip chọn khoảng thời gian
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _buildChip(label: "Tất cả",      value: "all",        timeChip: true),
            _buildChip(label: "Tháng này",   value: "this_month", timeChip: true),
            _buildChip(label: "Tháng trước", value: "last_month", timeChip: true),
            // Chip tùy chọn — bấm vào mở DateRangePicker
            GestureDetector(
              onTap: _openDateRangePicker,
              child: Chip(
                label: Text(
                  (_timeFilter == 'custom' && _customStartDate != null)
                      ? '${FormatHelper.formatDate(_customStartDate!)} → ${FormatHelper.formatDate(_customEndDate!)}'
                      : "Tùy chọn",
                  style: TextStyle(
                    color: _timeFilter == 'custom' ? Colors.black : Colors.white,
                    fontSize: 12,
                  ),
                ),
                backgroundColor: _timeFilter == 'custom' ? Colors.green : const Color(0xFF2C2C2E),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // =============================================
  // [7.10f] Widget: Bộ lọc nhóm (Category)
  // =============================================
  Widget _buildCategoryFilter() {
    return _buildFilterRow(
      label: "NHÓM",
      // Hiện tên nhóm đã chọn hoặc "Tất cả các nhóm"
      child: GestureDetector(
        onTap: _openCategoryPicker, // mở CategoryListScreen ở chế độ chọn
        child: Row(
          children: [
            // Icon nhỏ của category
            if (_selectedCategory != null)
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: IconHelper.buildCategoryIcon(
                    iconName: _selectedCategory!.ctgIconUrl,
                    size: 20,
                    placeholder: const Icon(Icons.category, color: Colors.grey, size: 18),
                  ),
                ),
              )
            else
              Icon(Icons.category, color: Colors.grey, size: 18),
            const SizedBox(width: 8),
            // Tên category
            Expanded(
              child: Text(
                _selectedCategory?.ctgName ?? "Tất cả các nhóm",
                style: TextStyle(
                  color: _selectedCategory != null ? Colors.white : Colors.grey,
                ),
              ),
            ),
            // Nút X xóa nhóm đã chọn
            if (_selectedCategory != null)
              GestureDetector(
                onTap: () => setState(() => _selectedCategory = null),
                child: const Icon(Icons.close, color: Colors.grey, size: 18),
              )
            else
              const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // =============================================
  // [7.10g] Widget: Phần kết quả tìm kiếm
  // =============================================
  Widget _buildResultSection() {
    // Chưa tìm lần nào → hiện placeholder
    if (!_hasSearched) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.search, color: Colors.grey, size: 48),
              SizedBox(height: 12),
              Text(
                "Đặt bộ lọc và bấm TÌM KIẾM",
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    // Đang tìm → hiện loading
    if (_isSearching) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator(color: Colors.green)),
      );
    }

    // Có lỗi → hiện lỗi
    if (_searchError != null) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(_searchError!, style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    // Không có kết quả → hiện empty state
    if (_results.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.search_off, color: Colors.grey, size: 48),
              SizedBox(height: 12),
              Text("Không tìm thấy kết quả", style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    // Có kết quả → hiện danh sách
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header số kết quả
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            "${_results.length} kết quả",
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
        // Danh sách giao dịch (dùng Column thay ListView để tránh lag)
        ..._results.asMap().entries.expand((entry) {
          final index = entry.key;
          final tx = entry.value;
          return [
            _buildResultItem(tx),
            if (index < _results.length - 1)
              const Divider(height: 1, color: Color(0xFF2C2C2E)),
          ];
        }).toList(),
      ],
    );
  }

  // =============================================
  // [7.10h] Widget: Một item kết quả
  // =============================================
  Widget _buildResultItem(TransactionResponse tx) {
    final isIncome = tx.categoryType == true; // true = Thu, false = Chi

    return ListTile(
      onTap: () => _openTransactionDetail(tx), // bấm → mở chi tiết
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey.shade800,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: IconHelper.buildCategoryIcon(
            iconName: tx.categoryIconUrl,
            size: 20,
            placeholder: const Icon(Icons.category, color: Colors.grey, size: 18),
          ),
        ),
      ),
      title: Text(
        tx.categoryName ?? "Không có nhóm",
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ghi chú (ẩn nếu null)
          if (tx.note != null && tx.note!.isNotEmpty)
            Text(tx.note!, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          // Ngày giao dịch
          Text(
            FormatHelper.formatDisplayDate(tx.transDate),
            style: const TextStyle(color: Colors.grey, fontSize: 11),
          ),
        ],
      ),
      trailing: Text(
        FormatHelper.formatVND(tx.amount),
        style: TextStyle(
          color: isIncome ? Colors.blue : Colors.red, // xanh dương = Thu, đỏ = Chi
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  // =============================================
  // [7.10i] _openTransactionDetail — Mở chi tiết giao dịch
  // =============================================
  void _openTransactionDetail(TransactionResponse tx) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => TransactionDetailSheet(
        transaction: tx,
        onEdit: () {
          // Đóng sheet trước
          Navigator.pop(context);
          // Navigate tới EditScreen
          _openEditTransaction(tx);
        },
        onDelete: () {
          Navigator.pop(context);
          // Xác nhận xóa
          _confirmDelete(tx);
        },
      ),
    );
  }

  // =============================================
  // [7.10j] _openEditTransaction — Mở màn sửa giao dịch
  // =============================================
  Future<void> _openEditTransaction(TransactionResponse tx) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionEditScreen(transaction: tx),
      ),
    );

    // Nếu sửa thành công → tìm kiếm lại để cập nhật kết quả
    if (result == true && mounted) {
      await _search();
    }
  }

  // =============================================
  // [7.10k] _confirmDelete — Xác nhận xóa giao dịch
  // =============================================
  void _confirmDelete(TransactionResponse tx) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Xóa giao dịch', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Bạn có chắc muốn xóa giao dịch này?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final provider = Provider.of<TransactionProvider>(context, listen: false);
              final success = await provider.deleteTransaction(tx.id);

              if (!mounted) return;

              if (success) {
                // Tìm kiếm lại sau khi xóa
                await _search();
              } else {
                _showSnackBar(provider.errorMessage ?? 'Xóa thất bại', isError: true);
              }
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // =============================================
  // [7.10l] _showSnackBar — Hiện thông báo
  // =============================================
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // =============================================
  // [7.11] Helper Widgets dùng chung
  // =============================================

  // Hàng filter: label nhỏ bên trái + nội dung bên phải
  Widget _buildFilterRow({required String label, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          // Label kiểu "GHI CHÚ", "VÍ", "VỚI"
          SizedBox(
            width: 90, // căn đều label
            child: _buildFilterLabel(label),
          ),
          // Nội dung filter (TextField, Dropdown, GestureDetector...)
          Expanded(child: child),
        ],
      ),
    );
  }

  // Label nhỏ màu xám cho mỗi filter row
  Widget _buildFilterLabel(String text) {
    return Text(text, style: const TextStyle(color: Colors.grey, fontSize: 12));
  }

  // Chip chọn kiểu filter (Tất cả / Lớn hơn / Tháng này...)
  Widget _buildChip({
    required String label,
    required String value,
    bool timeChip = false, // true = chip thời gian, false = chip số tiền
  }) {
    final isSelected = timeChip ? _timeFilter == value : _amountFilter == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (timeChip) {
            _timeFilter = value;
          } else {
            _amountFilter = value;
          }
        });
      },
      child: Chip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontSize: 12,
          ),
        ),
        backgroundColor: isSelected ? Colors.green : const Color(0xFF2C2C2E),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  // Đường kẻ phân cách giữa các filter row
  Widget _filterDivider() => const Divider(height: 1, color: Color(0xFF2C2C2E));
}

// ===========================================================
// [2] TransactionProvider — Quản lý state module Giao Dịch
// ===========================================================
// Trách nhiệm:
//   • Lưu trữ danh sách giao dịch (journal/grouped), date ranges, sources
//   • Gọi TransactionService + UtilService để thực hiện CRUD + load dữ liệu
//   • Thông báo UI rebuild khi dữ liệu thay đổi (notifyListeners)
//
// Cách dùng trong Screen:
//   final provider = Provider.of<TransactionProvider>(context);
//   provider.initialize(); // load lần đầu
//   provider.createTransaction(request); // tạo giao dịch
//
// API liên quan:
//   • GET  /api/utils/date-ranges          — thanh trượt khoảng thời gian
//   • GET  /api/user/wallets               — danh sách ví
//   • GET  /api/saving-goals/getAll        — danh sách mục tiêu tiết kiệm
//   • GET  /api/user/wallets/total-balance — tổng số dư tất cả ví
//   • GET  /api/transactions/journal       — giao dịch gom theo ngày
//   • GET  /api/transactions/grouped       — giao dịch gom theo danh mục
//   • POST /api/transactions               — tạo giao dịch mới
//   • PUT  /api/transactions/{id}          — cập nhật giao dịch
//   • DELETE /api/transactions/{id}        — xóa giao dịch
// ===========================================================

import 'package:flutter/foundation.dart';
import 'package:smart_money/core/enums/date_range_type.dart';
import 'package:smart_money/core/models/date_range_dto.dart';
import 'package:smart_money/core/helpers/icon_helper.dart';
import 'package:smart_money/modules/transaction/models/source_item.dart';
import 'package:smart_money/modules/transaction/models/view/daily_transaction_group.dart';
import 'package:smart_money/modules/transaction/models/view/category_transaction_group.dart';
import 'package:smart_money/modules/transaction/models/request/transaction_request.dart';
import 'package:smart_money/modules/transaction/services/transaction_service.dart';
import 'package:smart_money/modules/transaction/services/util_service.dart';

class TransactionProvider extends ChangeNotifier {

  // =============================================
  // [2.1] STATE — Khai báo biến state
  // =============================================

  // --- Chế độ xem ---
  bool _isGroupedMode = false;  // false = nhật ký (journal), true = nhóm (grouped)
  bool get isGroupedMode => _isGroupedMode;

  // --- Chế độ khoảng thời gian (DAILY, WEEKLY, MONTHLY, QUARTERLY, YEARLY) ---
  String _dateRangeMode = 'MONTHLY'; // mode mặc định là tháng
  String get dateRangeMode => _dateRangeMode;

  // --- Chế độ đặc biệt ---
  bool _isAllMode = false;    // true khi user chọn "Tất cả" — load toàn bộ giao dịch
  bool get isAllMode => _isAllMode;

  bool _isCustomMode = false; // true khi user chọn "Tùy chỉnh" — chọn startDate/endDate
  bool get isCustomMode => _isCustomMode;

  // --- Danh sách khoảng thời gian cho thanh trượt ---
  List<DateRangeDTO> _dateRanges = [];
  List<DateRangeDTO> get dateRanges => _dateRanges;

  DateRangeDTO? _selectedDateRange; // khoảng thời gian đang chọn
  DateRangeDTO? get selectedDateRange => _selectedDateRange;

  int _currentIndex = 0; // index của item CURRENT — dùng để auto-scroll
  int get currentIndex => _currentIndex;

  // --- Nguồn tiền (dropdown: Tổng cộng / Ví / Mục tiêu tiết kiệm) ---
  late SourceItem _selectedSource; // ví đang chọn
  SourceItem get selectedSource => _selectedSource;

  List<SourceItem> _sourceItems = []; // danh sách nguồn tiền
  List<SourceItem> get sourceItems => _sourceItems;

  // --- Data: Journal mode (gom theo ngày) ---
  List<DailyTransactionGroup> _journalGroups = [];
  List<DailyTransactionGroup> get journalGroups => _journalGroups;

  // --- Data: Grouped mode (gom theo danh mục) ---
  List<CategoryTransactionGroup> _groupedCategories = [];
  List<CategoryTransactionGroup> get groupedCategories => _groupedCategories;

  // --- UI state ---
  bool _isLoading = false;       // đang gọi API — hiện CircularProgressIndicator
  bool get isLoading => _isLoading;

  String? _errorMessage;         // lỗi từ server — hiện SnackBar đỏ
  String? get errorMessage => _errorMessage;

  String? _successMessage;       // thành công — hiện SnackBar xanh
  String? get successMessage => _successMessage;

  // =============================================
  // [2.2] COMPUTED — Tính toán từ journal data
  // =============================================
  // [NOTE] Backend đã tính netAmount cho mỗi ngày
  // Nhưng totalIncome/totalExpense cần tính từ transactions vì backend
  // chỉ trả netAmount (thu - chi) chứ không tách riêng

  /// Tổng tiền vào (Thu): tất cả transaction có categoryType=true
  double get totalIncome {
    double sum = 0;
    for (var group in _journalGroups) {
      for (var tx in group.transactions) {
        if (tx.categoryType) sum += tx.amount; // categoryType true = Thu nhập
      }
    }
    return sum;
  }

  /// Tổng tiền ra (Chi): tất cả transaction có categoryType=false
  double get totalExpense {
    double sum = 0;
    for (var group in _journalGroups) {
      for (var tx in group.transactions) {
        if (!tx.categoryType) sum += tx.amount; // categoryType false = Chi tiêu
      }
    }
    return sum;
  }

  /// Tổng ròng = tổng netAmount backend đã tính sẵn cho mỗi ngày
  double get netTotal {
    double sum = 0;
    for (var group in _journalGroups) {
      sum += group.netAmount; // netAmount = Thu - Chi trong ngày đó
    }
    return sum;
  }

  // =============================================
  // [2.3] CONSTRUCTOR
  // =============================================

  TransactionProvider() {
    _selectedSource = SourceItem.all(); // mặc định chọn "Tổng cộng"
  }

  // =============================================
  // [2.4] INITIALIZE — Khởi tạo dữ liệu lần đầu
  // =============================================
  // Gọi khi: initState() của TransactionListScreen
  // Flow:
  //   1. Gọi song song: date ranges + wallets + saving goals + total balance
  //   2. Tìm item CURRENT → set selectedDateRange
  //   3. Gộp wallets + savingGoals → sourceItems
  //   4. Gọi loadTransactionData() với selectedDateRange + selectedSource
  Future<void> initialize() async {
    // [OPTIMIZE] Tránh chạy lại nếu đang tải
    if (_isLoading) return;

    // Bước 1: Bật loading, xóa lỗi cũ
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Bước 2: Gọi song song — tải date ranges và sources (ví + mục tiêu)
      await Future.wait([
        _loadDateRanges(mode: _dateRangeMode),
        _loadSourceItems(),
      ]);

      // Bước 3: Tìm item CURRENT trong dateRanges → set làm selectedDateRange
      _findAndSelectCurrent();

      // Bước 4: Tải giao dịch lần đầu
      await _loadTransactionData();

      // Bước 5: Tắt loading
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      // Lỗi bất ngờ — lưu message để UI hiện
      _isLoading = false;
      _errorMessage = 'Lỗi khi tải dữ liệu: ${e.toString()}';
      notifyListeners();
    }
  }

  // =============================================
  // [2.4b] ENSURE SOURCE ITEMS LOADED
  // =============================================
  // Gọi khi: TransactionCreateScreen / TransactionEditScreen được mở
  // từ màn hình khác (DebtListScreen, FAB, v.v.) mà chưa qua TransactionListScreen.
  // Logic: Chỉ load nếu sourceItems chưa có dữ liệu (rỗng).
  // Không đụng đến dateRanges hay transactions — chỉ load ví + mục tiêu.
  Future<void> ensureSourceItemsLoaded() async {
    if (_sourceItems.isNotEmpty && _sourceItems.length > 1) return; // đã có data rồi, bỏ qua
    await _loadSourceItems();
    notifyListeners();
  }

  // =============================================
  // [2.5] CREATE — Tạo giao dịch mới
  // =============================================
  // Gọi khi: User bấm "Lưu" ở TransactionCreateScreen
  // API: POST /api/transactions
  // Trả về: true nếu thành công, false nếu thất bại
  // Lỗi server có thể trả:
  //   • "Số tiền phải lớn hơn 0" (400)
  //   • "Không tìm thấy ví" (400)
  //   • "Dữ liệu không hợp lệ" (400 — @Valid fail, data là Map field errors)
  Future<bool> createTransaction(TransactionRequest request) async {
    // Bước 1: Bật loading, xóa thông báo cũ
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    // Bước 2: Gọi API tạo mới
    final response = await TransactionService.create(request);

    // Bước 3: Xử lý kết quả
    if (response.success && response.data != null) {
      // Thành công → lưu message + reload dữ liệu
      _successMessage = response.message;
      // [FIX-BUG2] Reload cả giao dịch VÀ số dư ví (balance thay đổi sau mỗi giao dịch)
      await _reloadAfterChange();
      _isLoading = false;
      notifyListeners();
      return true;
    } else {
      // Thất bại → lưu lỗi để UI hiện SnackBar
      _errorMessage = _extractErrorMessage(response);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // =============================================
  // [2.6] UPDATE — Cập nhật giao dịch
  // =============================================
  // Gọi khi: User bấm "Lưu" ở TransactionEditScreen
  // API: PUT /api/transactions/{id}
  // Lỗi server:
  //   • "Bạn không có quyền sửa giao dịch này." (403)
  Future<bool> updateTransaction(int id, TransactionRequest request) async {
    // Bước 1: Bật loading, xóa thông báo cũ
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    // Bước 2: Gọi API cập nhật
    final response = await TransactionService.update(id, request);

    // Bước 3: Xử lý kết quả
    if (response.success && response.data != null) {
      _successMessage = response.message;
      // [FIX-BUG2] Reload cả giao dịch VÀ số dư ví
      await _reloadAfterChange();
      _isLoading = false;
      notifyListeners();
      return true;
    } else {
      _errorMessage = _extractErrorMessage(response);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // =============================================
  // [2.7] DELETE — Xóa giao dịch
  // =============================================
  // Gọi khi: User xác nhận xóa ở dialog
  // API: DELETE /api/transactions/{id}
  // Lỗi server:
  //   • "Bạn không có quyền xóa giao dịch này." (403)
  Future<bool> deleteTransaction(int id) async {
    // Bước 1: Bật loading
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    // Bước 2: Gọi API xóa
    final response = await TransactionService.delete(id);

    // Bước 3: Xử lý kết quả
    if (response.success) {
      _successMessage = response.message;
      // [FIX-BUG2] Reload cả giao dịch VÀ số dư ví (xóa giao dịch → hoàn tiền ví)
      await _reloadAfterChange();
      _isLoading = false;
      notifyListeners();
      return true;
    } else {
      _errorMessage = _extractErrorMessage(response);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // =============================================
  // [2.8] TOGGLE VIEW MODE — Chuyển Journal ↔ Grouped
  // =============================================
  // Gọi khi: User chọn "Xem theo nhật ký" / "Xem theo nhóm" từ menu 3 chấm
  Future<void> toggleViewMode() async {
    _isGroupedMode = !_isGroupedMode; // đảo chế độ xem
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _loadTransactionData();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Lỗi khi chuyển chế độ xem: ${e.toString()}';
      notifyListeners();
    }
  }

  // =============================================
  // [2.9] SELECT DATE RANGE — Chọn khoảng thời gian mới
  // =============================================
  // Gọi khi: User bấm vào 1 item trên thanh trượt ngày
  Future<void> selectDateRange(DateRangeDTO dateRange) async {
    if (_selectedDateRange == dateRange && !_isAllMode && !_isCustomMode) return;

    _selectedDateRange = dateRange;
    _isAllMode = false;
    _isCustomMode = false;

    // Cập nhật currentIndex để thanh trượt auto-scroll đến item được chọn
    for (int i = 0; i < _dateRanges.length; i++) {
      if (_dateRanges[i].label == dateRange.label) {
        _currentIndex = i;
        break;
      }
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _loadTransactionData();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Lỗi khi tải giao dịch: ${e.toString()}';
      notifyListeners();
    }
  }

  // =============================================
  // [2.10] SELECT SOURCE — Chọn nguồn tiền (ví/mục tiêu)
  // =============================================
  // Gọi khi: User chọn ví trong dropdown bottom sheet
  Future<void> selectSource(SourceItem source) async {
    if (_selectedSource.id == source.id && _selectedSource.type == source.type) return;

    _selectedSource = source;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _loadTransactionData();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Lỗi khi tải giao dịch: ${e.toString()}';
      notifyListeners();
    }
  }

  // =============================================
  // [2.11] CHANGE DATE RANGE MODE — Đổi chế độ thời gian
  // =============================================
  // Gọi khi: User chọn Ngày/Tuần/Tháng/Quý/Năm từ dialog
  // API: GET /api/utils/date-ranges?mode={mode}
  Future<void> changeDateRangeMode(String mode) async {
    _dateRangeMode = mode;
    _isAllMode = false;
    _isCustomMode = false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Bước 1: Tải lại date ranges với mode mới
      await _loadDateRanges(mode: mode);

      // Bước 2: Tìm item CURRENT và chọn
      _findAndSelectCurrent();

      // Bước 3: Tải lại giao dịch
      await _loadTransactionData();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Lỗi khi đổi chế độ: ${e.toString()}';
      notifyListeners();
    }
  }

  // =============================================
  // [2.12] LOAD ALL — Chế độ "Tất cả thời gian"
  // =============================================
  // Gọi khi: User chọn "Tất cả" trong dialog khoảng thời gian
  Future<void> loadAllTransactions() async {
    _isAllMode = true;
    _isCustomMode = false;
    _selectedDateRange = null;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _loadTransactionData();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Lỗi khi tải tất cả giao dịch: ${e.toString()}';
      notifyListeners();
    }
  }

  // =============================================
  // [2.13] LOAD CUSTOM — Chế độ "Tùy chỉnh"
  // =============================================
  // Gọi khi: User chọn "Tùy chỉnh" và pick startDate + endDate
  Future<void> loadCustomDateRange(DateTime startDate, DateTime endDate) async {
    _isCustomMode = true;
    _isAllMode = false;
    _selectedDateRange = DateRangeDTO.custom(startDate: startDate, endDate: endDate);
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _loadTransactionData();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Lỗi khi tải giao dịch tùy chỉnh: ${e.toString()}';
      notifyListeners();
    }
  }

  // =============================================
  // [2.14] REFRESH — Tải lại toàn bộ
  // =============================================
  // Gọi khi: User kéo refresh (pull-to-refresh)
  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();
    try {
      await Future.wait([
        _loadDateRanges(mode: _dateRangeMode),
        _loadSourceItems(),
      ]);
      _findAndSelectCurrent();
      await _loadTransactionData();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
    }
  }

  // =============================================
  // [2.14b] REFRESH SOURCE ITEMS — Cập nhật dropdown ví/mục tiêu ngay lập tức
  // =============================================
  // Gọi khi: Wallet hoặc SavingGoal bị xóa từ màn hình khác
  // Mục đích: Xóa ngay item đã bị soft-delete khỏi dropdown nguồn tiền
  // mà không cần đợi user chuyển tab (AnimatedSwitcher mới mount lại)
  Future<void> refreshSourceItems() async {
    await _loadSourceItems();
    notifyListeners();
  }

  // =============================================
  // [2.15] CLEAR MESSAGES — Xóa thông báo sau khi UI đã hiện
  // =============================================
  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    // KHÔNG cần notifyListeners — thường gọi sau khi đã pop màn hình
  }

  // =============================================
  // [2.15b] _reloadAfterChange — reload sau mỗi CRUD thành công
  // =============================================
  // [FIX-BUG2] Gọi sau create/update/delete để đồng bộ:
  //   1. Danh sách giao dịch (để list hiển thị đúng)
  //   2. Số dư ví + mục tiêu tiết kiệm (balance thay đổi sau mỗi giao dịch)
  //   3. Tổng số dư (total balance cũng thay đổi)
  // Nếu không gọi _loadSourceItems() → dropdown ví hiện số dư cũ
  Future<void> _reloadAfterChange() async {
    // Bước 1: Reload danh sách giao dịch theo khoảng thời gian hiện tại
    await _loadTransactionData();
    // Bước 2: Reload số dư ví + mục tiêu + tổng (balance đã thay đổi ở DB)
    await _loadSourceItems();
  }

  // =============================================
  // [2.16] PRIVATE — Load date ranges
  // =============================================
  Future<void> _loadDateRanges({String mode = 'MONTHLY'}) async {
    try {
      final response = await UtilService.getDateRanges(mode: mode);
      if (response.success && response.data != null) {
        _dateRanges = response.data!;
      }
    } catch (e) {
      debugPrint('❌ [TransactionProvider] Lỗi tải date ranges: $e');
    }
  }

  // =============================================
  // [2.17] PRIVATE — Load source items (ví + mục tiêu + tổng số dư)
  // =============================================
  Future<void> _loadSourceItems() async {
    try {
      // Gọi 3 API song song
      final responses = await Future.wait([
        UtilService.getAllWallets(),
        UtilService.getAllSavingGoals(forDropdown: true), // <--- MODIFIED HERE
        UtilService.getTotalBalance(),
      ]);

      final walletsResponse = responses[0] as dynamic;
      final goalsResponse = responses[1] as dynamic;
      final totalBalanceResponse = responses[2] as dynamic;

      // Bước 1: Tạo item "Tổng cộng" với total balance từ API
      final allItem = SourceItem.all();
      allItem.balance = (totalBalanceResponse.success ?? false)
          ? (totalBalanceResponse.data as num?)?.toDouble() ?? 0.0
          : 0.0;

      // Bước 2: Khởi tạo list với item "Tổng cộng" ở đầu
      _sourceItems = [allItem];

      // Bước 3: Thêm wallets vào list
      if ((walletsResponse.success ?? false) && walletsResponse.data != null) {
        for (var wallet in walletsResponse.data!) {
          // Convert filename.png → Cloudinary URL
          final walletIcon = IconHelper.buildCloudinaryUrl(wallet.goalImageUrl);

          _sourceItems.add(
            SourceItem.fromWallet(
              id: wallet.id,
              name: wallet.walletName,
              iconUrl: walletIcon,
              balance: wallet.balance,
            ),
          );
        }
      }

      // Bước 4: Thêm mục tiêu tiết kiệm vào list
      // Backend đã lọc isFinished=false server-side — chỉ trả về goal còn active
      if ((goalsResponse.success ?? false) && goalsResponse.data != null) {
        for (var goal in goalsResponse.data!) {

          // Convert filename.png → Cloudinary URL
          final goalIcon = IconHelper.buildCloudinaryUrl(goal.imageUrl);

          _sourceItems.add(
            SourceItem.fromSavingGoal(
              id: goal.id,
              name: goal.goalName,
              iconUrl: goalIcon,
              balance: goal.currentAmount,
            ),
          );
        }
      }

      // Bước 5: Cập nhật _selectedSource
      // [FIX-BUG2] Giữ source đang chọn nếu vẫn tồn tại trong list mới
      // (không reset về "Tổng cộng" mỗi lần reload — chỉ cập nhật balance)
      if (_sourceItems.isNotEmpty) {
        final currentId = _selectedSource.id;
        final currentType = _selectedSource.type;
        // Tìm lại source đang chọn trong list mới (để cập nhật balance)
        final found = _sourceItems.firstWhere(
          (s) => s.id == currentId && s.type == currentType,
          orElse: () => _sourceItems[0], // fallback về "Tổng cộng" nếu không tìm thấy
        );
        _selectedSource = found;
      }
    } catch (e) {
      debugPrint('❌ [TransactionProvider] Lỗi tải sources: $e');

      // FALLBACK: Nếu lỗi, vẫn tạo item "Tổng cộng" mặc định
      final fallbackItem = SourceItem.all();
      fallbackItem.balance = 0.0;
      _sourceItems = [fallbackItem];
      _selectedSource = fallbackItem;
    }
  }

  // =============================================
  // [2.18] PRIVATE — Tìm item CURRENT trong date ranges
  // =============================================
  void _findAndSelectCurrent() {
    _currentIndex = 0;
    DateRangeDTO? currentRange;

    // Tìm item có type = CURRENT trong danh sách
    for (int i = 0; i < _dateRanges.length; i++) {
      if (_dateRanges[i].type == DateRangeType.current) {
        currentRange = _dateRanges[i];
        _currentIndex = i;
        break;
      }
    }

    if (currentRange != null) {
      _selectedDateRange = currentRange; // chọn "Tháng này" / "Tuần này"
    } else if (_dateRanges.isNotEmpty) {
      _selectedDateRange = _dateRanges.last; // fallback: chọn item cuối
      _currentIndex = _dateRanges.length - 1;
    }
  }

  // =============================================
  // [2.19] PRIVATE — Load dữ liệu giao dịch (journal + grouped)
  // =============================================
  Future<void> _loadTransactionData() async {
    // Không load nếu chưa có date range (trừ khi đang ở mode "Tất cả")
    if (_selectedDateRange == null && !_isAllMode) return;

    try {
      // Xác định walletId / savingGoalId từ source đang chọn
      final walletId = _selectedSource.type == 'wallet' ? _selectedSource.id : null;
      final goalId = _selectedSource.type == 'saving_goal' ? _selectedSource.id : null;

      // Xác định startDate / endDate
      late DateTime startDate;
      late DateTime endDate;

      if (_isAllMode) {
        // Chế độ "Tất cả" → load khoảng rất rộng
        startDate = DateTime(2000, 1, 1);
        endDate = DateTime(2099, 12, 31, 23, 59, 59);
      } else if (_selectedDateRange != null) {
        // Chế độ bình thường → dùng date range đang chọn
        startDate = _selectedDateRange!.startDate;
        endDate = _selectedDateRange!.endDate;
      } else {
        return; // không có date range → không load
      }

      // Luôn load journal data (cần cho tính summary dù đang ở grouped mode)
      final journalResponse = await TransactionService.getJournalTransactions(
        startDate: startDate,
        endDate: endDate,
        walletId: walletId,
        savingGoalId: goalId,
      );

      if (journalResponse.success && journalResponse.data != null) {
        _journalGroups = journalResponse.data!;
      } else {
        _journalGroups = [];
        _errorMessage = journalResponse.message;
      }

      // Nếu đang ở grouped mode → load thêm grouped data
      if (_isGroupedMode) {
        final groupedResponse = await TransactionService.getGroupedTransactions(
          startDate: startDate,
          endDate: endDate,
          walletId: walletId,
          savingGoalId: goalId,
        );

        if (groupedResponse.success && groupedResponse.data != null) {
          _groupedCategories = groupedResponse.data!;
        } else {
          _groupedCategories = [];
          _errorMessage = groupedResponse.message;
        }
      }
    } catch (e) {
      _errorMessage = 'Lỗi khi tải giao dịch: ${e.toString()}';
    }
  }

  // =============================================
  // [2.20] HELPER — Trích xuất message lỗi từ response
  // =============================================
  // Xử lý 2 dạng lỗi từ Spring Boot:
  //   Dạng 1: IllegalArgumentException → response.message trực tiếp
  //   Dạng 2: @Valid fail → response.data là Map<field, message> → gom lại
  String _extractErrorMessage(dynamic response) {
    // Dạng 2: @Valid fail — data là Map chứa field errors
    if (response.data != null && response.data is Map) {
      final fieldErrors = response.data as Map;
      // Gom tất cả message lỗi thành 1 chuỗi, ngăn cách bởi dấu xuống dòng
      return fieldErrors.values.join('\n');
    }

    // Dạng 1: Lỗi thông thường — lấy message trực tiếp
    if (response.message != null && response.message.toString().isNotEmpty) {
      return response.message.toString();
    }

    // Fallback — không có message nào
    return 'Có lỗi xảy ra. Vui lòng thử lại.';
  }
}

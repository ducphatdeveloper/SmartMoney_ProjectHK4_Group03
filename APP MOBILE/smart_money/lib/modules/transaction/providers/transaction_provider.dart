// modules/transaction/providers/transaction_provider.dart
// Provider quản lý state cho màn hình sổ giao dịch
// Logic: Load date ranges, wallets, saving goals, transactions

import 'package:flutter/foundation.dart';
import 'package:smart_money/core/enums/date_range_type.dart';
import 'package:smart_money/core/models/date_range_dto.dart';
import 'package:smart_money/modules/transaction/models/source_item.dart';
import 'package:smart_money/modules/transaction/models/view/daily_transaction_group.dart';
import 'package:smart_money/modules/transaction/models/view/category_transaction_group.dart';
import 'package:smart_money/modules/transaction/services/transaction_service.dart';
import 'package:smart_money/modules/transaction/services/util_service.dart';

class TransactionProvider extends ChangeNotifier {
  // ===== STATE VARIABLES =====

  // Chế độ xem
  bool _isGroupedMode = false;
  bool get isGroupedMode => _isGroupedMode;

  // Chế độ khoảng thời gian (DAILY, WEEKLY, MONTHLY, QUARTERLY, YEARLY)
  String _dateRangeMode = 'MONTHLY';
  String get dateRangeMode => _dateRangeMode;

  // Chế độ đặc biệt: "Tất cả" hoặc "Tùy chỉnh"
  bool _isAllMode = false;
  bool get isAllMode => _isAllMode;

  bool _isCustomMode = false;
  bool get isCustomMode => _isCustomMode;

  // Khoảng thời gian
  List<DateRangeDTO> _dateRanges = [];
  List<DateRangeDTO> get dateRanges => _dateRanges;

  DateRangeDTO? _selectedDateRange;
  DateRangeDTO? get selectedDateRange => _selectedDateRange;

  // Index của CURRENT để auto-scroll
  int _currentIndex = 0;
  int get currentIndex => _currentIndex;

  // Nguồn tiền (dropdown)
  late SourceItem _selectedSource;
  SourceItem get selectedSource => _selectedSource;

  List<SourceItem> _sourceItems = [];
  List<SourceItem> get sourceItems => _sourceItems;

  // Data - Journal mode
  List<DailyTransactionGroup> _journalGroups = [];
  List<DailyTransactionGroup> get journalGroups => _journalGroups;

  // Data - Grouped mode
  List<CategoryTransactionGroup> _groupedCategories = [];
  List<CategoryTransactionGroup> get groupedCategories => _groupedCategories;

  // UI state
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ===== COMPUTED PROPERTIES (tính từ journal data — backend đã tính sẵn) =====

  /// Tổng tiền vào (Thu): tất cả transaction có categoryType=true
  double get totalIncome {
    double sum = 0;
    for (var group in _journalGroups) {
      for (var tx in group.transactions) {
        if (tx.categoryType) {
          sum += tx.amount;
        }
      }
    }
    return sum;
  }

  /// Tổng tiền ra (Chi): tất cả transaction có categoryType=false
  double get totalExpense {
    double sum = 0;
    for (var group in _journalGroups) {
      for (var tx in group.transactions) {
        if (!tx.categoryType) {
          sum += tx.amount;
        }
      }
    }
    return sum;
  }

  /// Tổng ròng = sum netAmount backend đã tính sẵn
  double get netTotal {
    double sum = 0;
    for (var group in _journalGroups) {
      sum += group.netAmount;
    }
    return sum;
  }

  // ===== CONSTRUCTOR =====
  TransactionProvider() {
    _selectedSource = SourceItem.all();
  }

  // ===== LIFECYCLE =====

  /// Khởi tạo dữ liệu khi màn hình load lần đầu
  Future<void> initialize() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Gọi song song
      await Future.wait([
        _loadDateRanges(),
        _loadSourceItems(),
      ]);

      // Tìm item CURRENT trong dateRanges → set làm selectedDateRange
      _findAndSelectCurrent();

      // Load dữ liệu giao dịch lần đầu
      await _loadTransactionData();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Lỗi khi tải dữ liệu: ${e.toString()}';
      notifyListeners();
      print('❌ [TransactionProvider] Exception: ${e.toString()}');
    }
  }

  // ===== PRIVATE METHODS =====

  /// Tìm item CURRENT trong dateRanges và set index để auto-scroll
  void _findAndSelectCurrent() {
    _currentIndex = 0;
    DateRangeDTO? currentRange;

    for (int i = 0; i < _dateRanges.length; i++) {
      if (_dateRanges[i].type == DateRangeType.current) {
        currentRange = _dateRanges[i];
        _currentIndex = i;
        break;
      }
    }

    if (currentRange != null) {
      _selectedDateRange = currentRange;
    } else if (_dateRanges.isNotEmpty) {
      _selectedDateRange = _dateRanges.last;
      _currentIndex = _dateRanges.length - 1;
    }
  }

  /// Load date ranges (Ngày, Tuần, Tháng, etc)
  Future<void> _loadDateRanges({String mode = 'MONTHLY'}) async {
    try {
      final response = await UtilService.getDateRanges(mode: mode);
      if (response.success && response.data != null) {
        _dateRanges = response.data!;
        print('✅ [TransactionProvider] Tải date ranges mode=$mode thành công: ${_dateRanges.length} items');
      } else {
        print('❌ [TransactionProvider] Tải date ranges thất bại: ${response.message}');
      }
    } catch (e) {
      print('❌ [TransactionProvider] Exception khi tải date ranges: ${e.toString()}');
    }
  }

  /// Load ví + mục tiêu tiết kiệm + tổng số dư
  Future<void> _loadSourceItems() async {
    try {
      final responses = await Future.wait([
        UtilService.getAllWallets(),
        UtilService.getAllSavingGoals(),
        UtilService.getTotalBalance(),
      ]);
      
      final walletsResponse = responses[0] as dynamic;
      final goalsResponse = responses[1] as dynamic;
      final totalBalanceResponse = responses[2] as dynamic;

      // Tạo item "Tổng cộng" với total balance
      final allItem = SourceItem.all();
      allItem.balance = (totalBalanceResponse.success ?? false) ? 
          (totalBalanceResponse.data as num?)?.toDouble() ?? 0.0 : 0.0;
      
      // LUÔN khởi tạo _sourceItems với ít nhất item "Tổng cộng"
      _sourceItems = [allItem];

      // Thêm wallets (kèm balance)
      if ((walletsResponse.success ?? false) && walletsResponse.data != null) {
        for (var wallet in walletsResponse.data!) {
          _sourceItems.add(
            SourceItem.fromWallet(
              id: wallet.id,
              name: wallet.walletName,
              iconUrl: wallet.goalImageUrl,
              balance: wallet.balance,
            ),
          );
        }
      } else {
        print('[TransactionProvider] Lỗi tải ví: ${walletsResponse.message}');
      }

      // Thêm mục tiêu tiết kiệm
      if ((goalsResponse.success ?? false) && goalsResponse.data != null) {
        for (var goal in goalsResponse.data!) {
          _sourceItems.add(
            SourceItem.fromSavingGoal(
              id: goal.id,
              name: goal.goalName,
              iconUrl: goal.imageUrl,
              balance: goal.currentAmount,
            ),
          );
        }
      } else {
        print('[TransactionProvider] Lỗi tải mục tiêu: ${goalsResponse.message}');
      }
      
      // CẬP NHẬT _selectedSource để trỏ đến item đầu tiên (luôn là "Tổng cộng")
      if (_sourceItems.isNotEmpty) {
        _selectedSource = _sourceItems[0];
      }
      
      print('✅ [TransactionProvider] Tải sources thành công: ${_sourceItems.length} items total');
    } catch (e) {
      print('❌ [TransactionProvider] Exception khi tải sources: ${e.toString()}');
      
      // FALLBACK: Nếu có lỗi, vẫn tạo item "Tổng cộng" mặc định
      final fallbackAllItem = SourceItem.all();
      fallbackAllItem.balance = 0.0;
      _sourceItems = [fallbackAllItem];
      _selectedSource = fallbackAllItem;
      
      print('⚠️ [TransactionProvider] Dùng fallback sources (chỉ có "Tổng cộng")');
    }
  }

  Future<void> _loadTransactionData() async {
    if (_selectedDateRange == null && !_isAllMode) return;

    try {
      final walletId = _selectedSource.type == 'wallet' ? _selectedSource.id : null;
      final goalId = _selectedSource.type == 'saving_goal' ? _selectedSource.id : null;

      // Xác định startDate/endDate
      late DateTime startDate;
      late DateTime endDate;

      if (_isAllMode) {
        startDate = DateTime(2000, 1, 1);
        endDate = DateTime(2099, 12, 31, 23, 59, 59);
      } else if (_selectedDateRange != null) {
        startDate = _selectedDateRange!.startDate;
        endDate = _selectedDateRange!.endDate;
      } else {
        return;
      }

      // Luôn load journal data (cần cho summary)
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

      // Nếu grouped mode thì load thêm grouped data
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

  // ===== PUBLIC METHODS =====

  /// Chuyển đổi giữa chế độ Journal và Grouped
  Future<void> toggleViewMode() async {
    _isGroupedMode = !_isGroupedMode;
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

  /// Chọn khoảng thời gian mới từ thanh trượt
  Future<void> selectDateRange(DateRangeDTO dateRange) async {
    _selectedDateRange = dateRange;
    _isAllMode = false;
    _isCustomMode = false;
    
    // Update currentIndex để auto-scroll đến item được chọn
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

  /// Chọn nguồn tiền (ví hoặc mục tiêu)
  Future<void> selectSource(SourceItem source) async {
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

  /// Đổi chế độ khoảng thời gian (DAILY, WEEKLY, MONTHLY, QUARTERLY, YEARLY)
  Future<void> changeDateRangeMode(String mode) async {
    _dateRangeMode = mode;
    _isAllMode = false;
    _isCustomMode = false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _loadDateRanges(mode: mode);  // ✅ Truyền mode vào
      _findAndSelectCurrent();
      await _loadTransactionData();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Lỗi khi đổi chế độ: ${e.toString()}';
      notifyListeners();
    }
  }

  /// Chế độ "Tất cả" — load toàn bộ giao dịch
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

  /// Chế độ "Tùy chỉnh" — user chọn startDate + endDate
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

  /// Refresh toàn bộ dữ liệu
  Future<void> refresh() async {
    await initialize();
  }
}


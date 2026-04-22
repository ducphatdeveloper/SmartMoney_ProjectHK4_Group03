import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/helpers/format_helper.dart';
import '../../../core/helpers/icon_helper.dart';
import '../../category/screens/category_list_screen.dart';
import '../../category/models/category_response.dart';
import '../../wallet/models/wallet_response.dart';
import 'package:smart_money/modules/budget/models/budget_request.dart';
import 'package:smart_money/modules/budget/models/budget_response.dart';
import 'package:smart_money/modules/budget/providers/budget_provider.dart';
import 'package:smart_money/modules/budget/enums/budget_type.dart';


class EditBudgetDetailScreen extends StatefulWidget {
  final BudgetResponse budget;
  final WalletResponse wallet;

  const EditBudgetDetailScreen({
    super.key,
    required this.budget,
    required this.wallet,
  });

  @override
  State<EditBudgetDetailScreen> createState() => _EditBudgetDetailScreenState();
}

class _EditBudgetDetailScreenState extends State<EditBudgetDetailScreen> {
  late BudgetResponse _currentBudget;
  final TextEditingController _amountCtrl = TextEditingController();
  CategoryResponse? category;
  WalletResponse? wallet;
  bool repeat = false;
  DateTimeRange? range;
  String periodType = "CUSTOM";
  bool _hasShownLimitWarning = false; // cờ kiểm tra đã show snack
  bool isTimeChanged = false;



  @override
  void initState() {
    super.initState();
    _currentBudget = widget.budget;
    wallet = widget.wallet;
    category = _currentBudget.categories.isNotEmpty ? _currentBudget.categories.first : null;
    repeat = _currentBudget.repeating;
    range = DateTimeRange(start: _currentBudget.beginDate, end: _currentBudget.endDate);
    periodType = _currentBudget.budgetType.apiValue; // 🔥 Set periodType từ budget hiện có

    _amountCtrl.text = NumberFormat('#,###', 'vi_VN').format(_currentBudget.amount);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _onAmountChanged(String value) {
    final raw = value.replaceAll(RegExp(r'[.,]'), '');
    int number = int.tryParse(raw) ?? 0;

    // Giới hạn 1000 tỷ
    const MAX_AMOUNT = 1000000000000; // 1000 tỷ

    if (number > MAX_AMOUNT) {
      number = MAX_AMOUNT;

      if (!_hasShownLimitWarning) {
        _hasShownLimitWarning = true;
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text("Amount must not exceed 1000 billion"),
              duration: Duration(seconds: 2),
            ),
          );
      }
    } else {
      _hasShownLimitWarning = false; // reset khi <= 1000  tỷ
    }

    final formatted = NumberFormat('#,###', 'vi_VN').format(number);

    _amountCtrl.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }


  int get amountValue => int.tryParse(_amountCtrl.text.replaceAll(RegExp(r'[.,]'), '')) ?? 0;

  Future pickCategory() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CategoryListScreen(isSelectMode: true, initialTab: 'expense'),
      ),
    );
    if (result != null && mounted) setState(() => category = result);
  }

  void setRange(DateTime start, DateTime end) {
    setState(() {
      range = DateTimeRange(start: start, end: end);
      isTimeChanged = true; // 🔥 quan trọng
    });
  }


  void pickQuickRange() async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);
    final startOfYear = DateTime(now.year, 1, 1);
    final endOfYear = DateTime(now.year, 12, 31);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.hardEdge,
        child: ListView(
          shrinkWrap: true,
          children: [
            const SizedBox(height: 12),
            const Center(
              child: Text(
                "Time period",
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
            _sheetBtn("This week (${_f(startOfWeek)} - ${_f(endOfWeek)})", () {
              setRange(startOfWeek, endOfWeek);
              periodType = "WEEKLY";
              Navigator.pop(context);
            }),
            _sheetBtn("This month (${_f(startOfMonth)} - ${_f(endOfMonth)})", () {
              setRange(startOfMonth, endOfMonth);
              periodType = "MONTHLY";
              Navigator.pop(context);
            }),
            _sheetBtn("This year (${_f(startOfYear)} - ${_f(endOfYear)})", () {
              setRange(startOfYear, endOfYear);
              periodType = "YEARLY";
              Navigator.pop(context);
            }),
            _sheetBtn("Custom", () async {
              Navigator.pop(context);
              final result = await showDateRangePicker(
                context: context,
                firstDate: DateTime.now(),
                lastDate: DateTime(2030),
                initialDateRange: range,
              );
              if (result != null && mounted) setState(() {
                range = result;
                periodType = "CUSTOM";
              });
            }),
            const SizedBox(height: 8),
            _sheetBtn("Cancel", () => Navigator.pop(context), isCancel: true),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _f(DateTime dt) => FormatHelper.formatDate(dt);

  Widget _sheetBtn(String text, VoidCallback onTap, {bool isCancel = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isCancel ? Colors.black45 : Colors.grey.shade800,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(color: isCancel ? Colors.redAccent : Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }

  String? _validateBudgetType(String type, DateTime start, DateTime end) {
    final days = end.difference(start).inDays + 1;

    switch (type) {
      case "WEEKLY":
        if (days != 7) {
          return "Weekly budget must be exactly 7 days";
        }
        break;
      case "MONTHLY":
        if (start.day != 1 || end.day != DateTime(start.year, start.month + 1, 0).day) {
          return "Monthly budget must be from first to last day of month";
        }
        break;
      case "YEARLY":
        if (start.day != 1 || start.month != 1 || end.day != 31 || end.month != 12) {
          return "Yearly budget must be from 01/01 to 12/31";
        }
        break;
      case "CUSTOM":
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);
        final startDate = DateTime(start.year, start.month, start.day);
        if (startDate.isBefore(todayDate)) {
          return "Start date must be today or later for custom budget";
        }
        break;
    }
    return null;
  }

  Future<void> save() async {
    // if (amountValue <= 0 || range == null || category == null)
    if (amountValue <= 0 || category == null)
    {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter all required information")),
      );
      return;
    }

    // Validate theo budget type
    // if (range != null) {
    //   final validationError = _validateBudgetType(periodType, range!.start, range!.end);
    //   if (validationError != null) {
    //     ScaffoldMessenger.of(context).showSnackBar(
    //       SnackBar(content: Text(validationError)),
    //     );
    //     return;
    //   }
    // }
    if (isTimeChanged && range != null) {
      final validationError = _validateBudgetType(periodType, range!.start, range!.end);
      if (validationError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(validationError)),
        );
        return;
      }
    }


    final request = BudgetRequest(
      walletId: wallet!.id,
      amount: amountValue.toDouble(),
      beginDate: range!.start,
      endDate: range!.end,
      repeating: repeat,
      allCategories: false,
      categoryId: category!.id,
      budgetType: periodType,
    );

    final provider = context.read<BudgetProvider>();
    final success = await provider.updateBudget(_currentBudget.id, request);

    if (success && mounted) {
      final updatedBudget = _currentBudget.copyWith(
        walletId: wallet?.id,
        walletName: wallet?.walletName,
        beginDate: range?.start,
        endDate: range?.end,
        amount: amountValue.toDouble(),
        categories: category != null ? [category!] : [],
        primaryCategoryIconUrl: category?.ctgIconUrl,
        repeating: repeat,
        // budgetType vẫn giữ nguyên nếu không thay đổi
      );

      Navigator.pop(context, updatedBudget); // 🔹 pop kèm dữ liệu
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Update failed")),
      );
      Navigator.pop(context); // 🔹 Chỉ pop, không cần BudgetResponse
    }

  }


  @override
  Widget build(BuildContext context) {
    final isValid = amountValue > 0 && range != null && category != null;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),

        actions: const [
          SizedBox(width: 48), // 👈 FIX: cân với leading
        ],

        title: const Text(
          "Edit budget",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),






      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: isValid ? save : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: isValid ? Colors.green : Colors.grey.shade800,
          ),
          child: const Text("Save"),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(
            child: Column(
              children: [
                // CATEGORY
                ListTile(
                  leading: ClipOval(
                    child: IconHelper.buildCategoryIcon(
                      iconName: category?.ctgIconUrl,
                      size: 44,
                      placeholder: const CircleAvatar(
                        radius: 22,
                        child: Icon(Icons.category),
                      ),
                    ),
                  ),
                  title: Text(category?.ctgName ?? "Select category", style: const TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: pickCategory,
                ),
                const Divider(),

                // AMOUNT
                TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 22, color: Colors.white),
                  decoration: const InputDecoration(prefixText: "VND ", border: InputBorder.none),
                  onChanged: _onAmountChanged,
                ),
                const Divider(),

                // DATE RANGE
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text(
                    range == null
                        ? "Select time"
                        : "${FormatHelper.formatDate(range!.start)} - ${FormatHelper.formatDate(range!.end)}",
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: pickQuickRange,
                ),
                const Divider(),

                // WALLET
                ListTile(
                  leading: IconHelper.buildCircleAvatar(
                    iconUrl: wallet?.goalImageUrl,
                    radius: 22,
                  ),
                  title: Text(
                    wallet?.walletName ?? "No wallet",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    wallet?.currencyCode ?? "VND",
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.lock, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // REPEAT SWITCH
          _card(
            child: SwitchListTile(
              value: repeat,
              onChanged: (v) => setState(() => repeat = v),
              title: const Text("Repeat this budget", style: TextStyle(color: Colors.white)),
              subtitle: const Text("Budget will automatically repeat in next period", style: TextStyle(color: Colors.grey)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(16)),
      child: child,
    );
  }
}

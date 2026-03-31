import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/helpers/format_helper.dart';
import '../../../core/helpers/icon_helper.dart';
import '../../category/screens/category_list_screen.dart';
import '../../category/models/category_response.dart';
import 'package:smart_money/modules/wallet/screens/SelectWalletScreen.dart';
import 'package:smart_money/modules/wallet/models/wallet_response.dart';
import 'package:smart_money/modules/budget/models/budget_request.dart';
import 'package:smart_money/modules/budget/models/budget_response.dart';
import 'package:smart_money/modules/budget/services/budget_service.dart';

class EditBudgetDetailScreen extends StatefulWidget {
  final BudgetResponse budget;

  const EditBudgetDetailScreen({super.key, required this.budget});

  @override
  State<EditBudgetDetailScreen> createState() =>
      _EditBudgetDetailScreenState();
}

class _EditBudgetDetailScreenState extends State<EditBudgetDetailScreen> {
  final TextEditingController _amountCtrl = TextEditingController();

  CategoryResponse? category;
  WalletResponse? wallet;

  bool repeat = false;
  DateTimeRange? range;

  @override
  void initState() {
    super.initState();

    final b = widget.budget;

    // ❌ bỏ đoạn tạo WalletResponse
    // wallet = WalletResponse(...)

    // ✅ giữ null → user tự chọn lại (giống Add)
    wallet = null;

    // category
    if (b.categories.isNotEmpty) {
      category = b.categories.first;
    }

    repeat = b.repeating ?? false;

    range = DateTimeRange(
      start: b.beginDate,
      end: b.endDate,
    );

    _amountCtrl.text =
        NumberFormat('#,###', 'vi_VN').format(b.amount);
  }

  // ================= FORMAT =================
  void _onAmountChanged(String value) {
    final raw = value.replaceAll('.', '').replaceAll(',', '');
    final number = int.tryParse(raw) ?? 0;

    final formatted = NumberFormat('#,###', 'vi_VN').format(number);

    _amountCtrl.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  int get amountValue {
    return int.tryParse(
      _amountCtrl.text.replaceAll('.', '').replaceAll(',', ''),
    ) ??
        0;
  }

  // ================= PICK =================
  Future pickCategory() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CategoryListScreen(
          isSelectMode: true,
          initialTab: 'expense',
        ),
      ),
    );

    if (result != null) {
      setState(() => category = result);
    }
  }

  Future pickWallet() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SelectWalletScreen(),
      ),
    );

    if (result != null) {
      setState(() => wallet = result);
    }
  }

  // ================= DATE =================
  void setRange(DateTime start, DateTime end) {
    setState(() {
      range = DateTimeRange(start: start, end: end);
    });
  }

  void pickQuickRange() {
    final now = DateTime.now();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      builder: (_) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _rangeItem("Tuần này", () {
              final start = now.subtract(Duration(days: now.weekday - 1));
              final end = start.add(const Duration(days: 6));
              setRange(start, end);
              Navigator.pop(context);
            }),
            _rangeItem("Tháng này", () {
              final start = DateTime(now.year, now.month, 1);
              final end = DateTime(now.year, now.month + 1, 0);
              setRange(start, end);
              Navigator.pop(context);
            }),
            _rangeItem("Tuỳ chỉnh", () async {
              Navigator.pop(context);
              final result = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2023),
                lastDate: DateTime(2030),
                initialDateRange: range,
              );
              if (result != null) setState(() => range = result);
            }),
          ],
        );
      },
    );
  }

  Widget _rangeItem(String text, VoidCallback onTap) {
    return ListTile(
      title: Text(text, style: const TextStyle(color: Colors.white)),
      onTap: onTap,
    );
  }

  // ================= SAVE =================
  Future<void> save() async {
    if (amountValue <= 0 ||
        range == null ||
        wallet == null ||
        category == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng nhập đầy đủ thông tin")),
      );
      return;
    }

    final request = BudgetRequest(
      walletId: wallet!.id,
      amount: amountValue.toDouble(),
      beginDate: range!.start,
      endDate: range!.end,
      repeating: repeat,
      allCategories: false,
      categoryId: category!.id,
      budgetType: getBudgetType(range),
    );

    final res = await BudgetService()
        .update(widget.budget.id, request);

    if (!mounted) return;

    if (res.success && res.data != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pop(context, res.data);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message ?? "Cập nhật thất bại")),
      );
    }
  }
  String getBudgetType(DateTimeRange? range) {
    if (range == null) return "CUSTOM";

    final days = range.duration.inDays + 1;

    if (days <= 7) return "WEEKLY";
    if (days <= 31) return "MONTHLY";
    if (days <= 366) return "YEARLY";

    return "CUSTOM";
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    final isValid =
        amountValue > 0 && range != null && wallet != null && category != null;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Sửa ngân sách"),
        backgroundColor: Colors.black,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Huỷ"),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: isValid ? save : null,
          style: ElevatedButton.styleFrom(
            backgroundColor:
            isValid ? Colors.green : Colors.grey.shade800,
          ),
          child: const Text("Lưu"),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(
            child: Column(
              children: [
                ListTile(
                  leading: IconHelper.buildCircleAvatar(
                    iconUrl: category?.ctgIconUrl,
                    radius: 20,
                  ),
                  title: Text(
                    category?.ctgName ?? "Chọn nhóm",
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: pickCategory,
                ),
                const Divider(),
                TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 22, color: Colors.white),
                  decoration: const InputDecoration(
                    prefixText: "VND ",
                    border: InputBorder.none,
                  ),
                  onChanged: _onAmountChanged,
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text(
                    range == null
                        ? "Chọn thời gian"
                        : "${FormatHelper.formatDate(range!.start)} - ${FormatHelper.formatDate(range!.end)}",
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: pickQuickRange,
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet),
                  title: Text(
                    wallet?.walletName ?? "Chọn ví",
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: pickWallet,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _card(
            child: SwitchListTile(
              value: repeat,
              onChanged: (v) => setState(() => repeat = v),
              title: const Text(
                "Lặp lại ngân sách này",
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                "Ngân sách sẽ tự lặp lại kỳ tiếp theo",
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}
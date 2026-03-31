import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/helpers/format_helper.dart';
import '../../../core/helpers/icon_helper.dart';
import '../../category/screens/category_list_screen.dart';
import '../../category/models/category_response.dart';
import '../../wallet/screens/SelectWalletScreen.dart';
import '../../wallet/models/wallet_response.dart';
import '../models/budget_request.dart';
import '../services/budget_service.dart';

class AddBudgetScreen extends StatefulWidget {
  final WalletResponse? wallet;

  const AddBudgetScreen({super.key, this.wallet});

  @override
  State<AddBudgetScreen> createState() => _AddBudgetScreenState();
}

class _AddBudgetScreenState extends State<AddBudgetScreen> {
  final TextEditingController _amountCtrl = TextEditingController();

  CategoryResponse? category;
  WalletResponse? wallet;

  bool repeat = false;
  DateTimeRange? range;

  String periodType = "CUSTOM"; // 🔥 thêm

  @override
  void initState() {
    super.initState();
    wallet = widget.wallet;
  }

  // =========================
  // FORMAT TIỀN
  // =========================
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

  // =========================
  // CATEGORY
  // =========================
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

  // =========================
  // WALLET
  // =========================
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

  // =========================
  // DATE RANGE
  // =========================
  void setRange(DateTime start, DateTime end, String type) {
    setState(() {
      range = DateTimeRange(start: start, end: end);
      periodType = type;
    });
  }

  String _f(DateTime d) {
    return "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}";
  }

  void pickQuickRange() {
    final now = DateTime.now();

    DateTime startOfWeek =
    now.subtract(Duration(days: now.weekday - 1));
    DateTime endOfWeek = startOfWeek.add(const Duration(days: 6));

    DateTime startOfMonth = DateTime(now.year, now.month, 1);
    DateTime endOfMonth = DateTime(now.year, now.month + 1, 0);

    DateTime startOfYear = DateTime(now.year, 1, 1);
    DateTime endOfYear = DateTime(now.year, 12, 31);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 🔥 QUAN TRỌNG
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          margin: const EdgeInsets.all(16),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(24),
          ),
          clipBehavior: Clip.hardEdge, // 🔥 tránh tràn góc
          child: ListView(
            shrinkWrap: true,
            children: [
              const SizedBox(height: 12),

              const Center(
                child: Text(
                  "Khoảng thời gian",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              _sheetBtn(
                "Tuần này (${_f(startOfWeek)} - ${_f(endOfWeek)})",
                    () {
                  setRange(startOfWeek, endOfWeek, "WEEKLY");
                  Navigator.pop(context);
                },
              ),

              _sheetBtn(
                "Tháng này (${_f(startOfMonth)} - ${_f(endOfMonth)})",
                    () {
                  setRange(startOfMonth, endOfMonth, "MONTHLY");
                  Navigator.pop(context);
                },
              ),

              _sheetBtn(
                "Năm nay (${_f(startOfYear)} - ${_f(endOfYear)})",
                    () {
                  setRange(startOfYear, endOfYear, "YEARLY");
                  Navigator.pop(context);
                },
              ),

              _sheetBtn(
                "Tuỳ chỉnh",
                    () async {
                  Navigator.pop(context);

                  final result = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2023),
                    lastDate: DateTime(2030),
                  );

                  if (result != null) {
                    setState(() {
                      range = result;
                      periodType = "CUSTOM";
                    });
                  }
                },
              ),

              const SizedBox(height: 8),

              _sheetBtn(
                "Huỷ",
                    () => Navigator.pop(context),
                isCancel: true,
              ),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _sheetBtn(String text, VoidCallback onTap,
      {bool isCancel = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isCancel
                ? Colors.black45
                : Colors.grey.shade800,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              color: isCancel ? Colors.redAccent : Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  // =========================
  // SAVE
  // =========================
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
      budgetType: periodType, // 🔥 chuẩn enum backend
    );

    final res = await BudgetService().create(request);

    if (!mounted) return;

    if (res.success) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message ?? "Tạo thất bại")),
      );
    }
  }

  // =========================
  // UI
  // =========================
  @override
  Widget build(BuildContext context) {
    final isValid =
        amountValue > 0 && range != null && wallet != null && category != null;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Thêm ngân sách"),
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
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                    style: const TextStyle(
                        fontSize: 22, color: Colors.white),
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
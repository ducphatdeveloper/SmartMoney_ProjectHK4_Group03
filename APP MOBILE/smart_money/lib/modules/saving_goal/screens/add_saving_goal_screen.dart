import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smart_money/core/helpers/icon_helper.dart';

import '../models/saving_goal_response.dart';
import '../providers/saving_goal_provider.dart';
import '../models/saving_goal_request.dart';
import '../../category/models/icon_dto.dart';
import 'package:smart_money/modules/category/screens/icon_picker_screen.dart';

class AddSavingGoalScreen extends StatefulWidget {
  final SavingGoalResponse? restoreGoal;
  const AddSavingGoalScreen({super.key, this.restoreGoal});

  @override
  State<AddSavingGoalScreen> createState() => _AddSavingGoalScreenState();
}

class _AddSavingGoalScreenState extends State<AddSavingGoalScreen> {
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  final _initialController = TextEditingController();

  final String _currency = "VND";
  bool _notify = true;
  bool _reportable = true;
  DateTime? _endDate;
  bool _isSaving = false;

  /// Default Icon
  String? _selectedIconUrl = "https://res.cloudinary.com/drd2hsocc/image/upload/v1774385006/icon_basic_wallet.png";

  @override
  void initState() {
    super.initState();
    // 🎯 LOGIC RESTORE DATA: Nếu có restoreGoal, điền thông tin cũ vào các trường
    if (widget.restoreGoal != null) {
      final goal = widget.restoreGoal!;
      _nameController.text = goal.goalName;
      _targetController.text = goal.targetAmount.toInt().toString();
      _initialController.text = goal.currentAmount.toInt().toString();
      _selectedIconUrl = goal.imageUrl;

      if (goal.endDate.isAfter(DateTime.now())) {
        _endDate = goal.endDate;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _initialController.dispose();
    super.dispose();
  }

  // --- VALIDATION & HELPER METHODS (GIỮ NGUYÊN) ---

  String? _validateData() {
    final name = _nameController.text.trim();
    final targetStr = _targetController.text.trim();
    final initialStr = _initialController.text.trim();

    if (name.isEmpty) return "Goal name cannot be empty";
    if (targetStr.isEmpty) return "Target amount cannot be empty";

    final targetAmount = double.tryParse(targetStr.replaceAll(',', ''));
    if (targetAmount == null || targetAmount <= 0) return "Invalid target amount";

    final initialAmount = double.tryParse(initialStr.replaceAll(',', '')) ?? 0;
    if (initialAmount < 0) return "Initial amount cannot be negative";
    if (initialAmount > targetAmount) return "Initial amount cannot exceed target";

    if (_endDate == null) return "Please select a target date";
    if (_endDate!.isBefore(DateTime.now().subtract(const Duration(days: 1)))) {
      return "End date cannot be in the past";
    }
    return null;
  }

  void _openIconPicker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const IconPickerScreen()),
    );
    if (result != null && result is IconDto && mounted) {
      setState(() => _selectedIconUrl = result.url);
    }
  }

  Future<void> _handleSave() async {
    final error = _validateData();
    if (error != null) {
      _showSnackBar(error, isError: true);
      return;
    }

    setState(() => _isSaving = true);

    final double targetAmount = double.parse(_targetController.text.replaceAll(',', ''));
    final double initialAmount = double.tryParse(_initialController.text.replaceAll(',', '')) ?? 0;

    final request = SavingGoalRequest(
      goalName: _nameController.text.trim(),
      targetAmount: targetAmount,
      initialAmount: initialAmount,
      currencyCode: _currency,
      endDate: _endDate!,
      notified: _notify,
      reportable: _reportable,
      goalImageUrl: _selectedIconUrl,
      amount: initialAmount,
    );

    final provider = Provider.of<SavingGoalProvider>(context, listen: false);
    final success = await provider.createGoal(request);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      await provider.loadGoals(false, forceRefresh: true);
      _showSnackBar(widget.restoreGoal != null ? "Goal restored successfully!" : "Goal created successfully!", isError: false);

      // 🎯 CẬP NHẬT LOGIC ĐIỀU HƯỚNG
      if (widget.restoreGoal != null) {
        // Nếu là Restore: Back 2 lần để về hẳn ListView
        Navigator.of(context).pop(); // Thoát màn hình AddSavingGoal
        Navigator.of(context).pop(true); // Thoát màn hình Detail
      } else {
        // Nếu tạo mới: Chỉ back 1 lần
        Navigator.of(context).pop(true);
      }
    } else {
      _showSnackBar(provider.errorMessage ?? "Failed to save goal", isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- UI BUILDER (GIỮ NGUYÊN CẤU TRÚC) ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: Text(widget.restoreGoal != null ? "Restore Saving Goal" : "New Saving Goal",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _handleSave,
            child: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.greenAccent))
                : const Text("SAVE", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildFieldWrapper(
            child: Row(
              children: [
                GestureDetector(
                  onTap: _openIconPicker,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.greenAccent.withOpacity(0.5), width: 2)),
                        child: IconHelper.buildCircleAvatar(iconUrl: _selectedIconUrl, radius: 30, backgroundColor: const Color(0xFF1C1C1E)),
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle, border: Border.all(color: Colors.black, width: 2)),
                        child: const Icon(Icons.edit_rounded, size: 12, color: Colors.white),
                      )
                    ],
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    autofocus: widget.restoreGoal == null,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
                    decoration: const InputDecoration(
                      labelText: "Goal Name",
                      hintText: "What are you saving for?",
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Color(0xFF48484A)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _sectionLabel("FINANCIAL DETAILS"),
          _buildFieldWrapper(
            child: Column(
              children: [
                _buildTextField(
                  controller: _targetController,
                  label: "Target Amount",
                  hint: "0",
                  icon: Icons.track_changes,
                  iconColor: Colors.greenAccent,
                ),
                const Divider(height: 1, color: Colors.white10, indent: 40),
                _buildTextField(
                  controller: _initialController,
                  label: "Initial Amount",
                  hint: "0",
                  icon: Icons.account_balance_wallet,
                  iconColor: Colors.blueAccent,
                ),
                const Divider(height: 1, color: Colors.white10, indent: 40),
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.currency_exchange, color: Colors.orangeAccent, size: 22),
                  title: Text("Currency", style: TextStyle(color: Colors.grey, fontSize: 14)),
                  trailing: Text("VND (₫)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _sectionLabel("SCHEDULE & SETTINGS"),
          _buildFieldWrapper(
            child: Column(
              children: [
                ListTile(
                  onTap: _pickDate,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_month, color: Colors.redAccent, size: 22),
                  title: Text(
                    _endDate == null ? "Target Date" : DateFormat('MMMM dd, yyyy').format(_endDate!),
                    style: TextStyle(color: _endDate == null ? Colors.grey : Colors.white, fontSize: 15),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                ),
                const Divider(height: 1, color: Colors.white10, indent: 40),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.notifications_active_outlined, color: Colors.purpleAccent, size: 22),
                  title: const Text("Enable Notifications", style: TextStyle(color: Colors.white, fontSize: 15)),
                  value: _notify,
                  activeColor: Colors.purpleAccent,
                  onChanged: (val) => setState(() => _notify = val),
                ),
                const Divider(height: 1, color: Colors.white10, indent: 40),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.insights_rounded, color: Colors.tealAccent, size: 22),
                  title: const Text("Include in Reports", style: TextStyle(color: Colors.white, fontSize: 15)),
                  value: _reportable,
                  activeColor: Colors.greenAccent,
                  onChanged: (val) => setState(() => _reportable = val),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(left: 8, bottom: 8),
    child: Text(text, style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
  );

  Widget _buildFieldWrapper({required Widget child}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.05))),
    child: child,
  );

  Widget _buildTextField({required TextEditingController controller, required String label, String? hint, required IconData icon, Color iconColor = Colors.grey}) => TextField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      icon: Icon(icon, color: iconColor, size: 22),
      labelText: label,
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white10, fontSize: 14),
      labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
      border: InputBorder.none,
    ),
  );

  void _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Colors.greenAccent, onPrimary: Colors.black, surface: Color(0xFF1C1C1E))), child: child!),
    );
    if (date != null) setState(() => _endDate = date);
  }
}
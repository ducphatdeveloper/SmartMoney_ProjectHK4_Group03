import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smart_money/core/helpers/icon_helper.dart';

import '../providers/saving_goal_provider.dart';
import '../models/saving_goal_request.dart';
import '../models/saving_goal_response.dart';
import '../../category/models/icon_dto.dart';
import 'package:smart_money/modules/category/screens/icon_picker_screen.dart';

class EditSavingGoalScreen extends StatefulWidget {
  final SavingGoalResponse goal;

  const EditSavingGoalScreen({super.key, required this.goal});

  @override
  State<EditSavingGoalScreen> createState() => _EditSavingGoalScreenState();
}

class _EditSavingGoalScreenState extends State<EditSavingGoalScreen> {
  late TextEditingController _nameController;
  late TextEditingController _targetController;
  late TextEditingController _currentController;

  DateTime? _endDate;
  late String _currency;
  bool _notify = true;
  bool _reportable = true;
  bool _isSaving = false;
  String? _selectedIconUrl;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.goal.goalName);
    _targetController = TextEditingController(text: widget.goal.targetAmount.toInt().toString());
    _currentController = TextEditingController(text: widget.goal.currentAmount.toInt().toString());

    _currency = widget.goal.currencyCode ?? "VND";
    _endDate = widget.goal.endDate;
    _notify = widget.goal.notified ?? true;
    _reportable = widget.goal.reportable ?? true;
    _selectedIconUrl = widget.goal.imageUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _currentController.dispose();
    super.dispose();
  }

  String? _validateData() {
    final name = _nameController.text.trim();
    final targetStr = _targetController.text.trim();
    final currentStr = _currentController.text.trim();

    if (name.isEmpty) return "Tên mục tiêu không được để trống";
    if (targetStr.isEmpty) return "Số tiền mục tiêu không được để trống";

    final targetAmount = double.tryParse(targetStr);
    if (targetAmount == null || targetAmount <= 0) return "Số tiền mục tiêu phải lớn hơn 0";
    if (targetAmount >= 10000000000) return "Số tiền mục tiêu phải nhỏ hơn 10 tỷ";

    if (currentStr.isEmpty) return "Số tiền hiện tại không được để trống";
    final currentAmount = double.tryParse(currentStr);
    if (currentAmount == null || currentAmount < 0) return "Số tiền hiện tại không hợp lệ";

    if (currentAmount > targetAmount) {
      return "Số dư hiện tại không được lớn hơn mục tiêu";
    }

    if (_endDate == null) return "Vui lòng chọn ngày kết thúc";

    return null;
  }

  void _openIconPicker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const IconPickerScreen()),
    );

    if (result != null && result is IconDto && mounted) {
      setState(() {
        _selectedIconUrl = result.url;
      });
    }
  }

  Future<void> _handleSave() async {
    final error = _validateData();
    if (error != null) {
      _showSnackBar(error, isError: true);
      return;
    }

    setState(() => _isSaving = true);

    final double targetAmount = double.parse(_targetController.text.trim());
    final double currentAmount = double.parse(_currentController.text.trim());

    final request = SavingGoalRequest(
      goalName: _nameController.text.trim(),
      targetAmount: targetAmount,
      initialAmount: currentAmount,
      currencyCode: _currency,
      endDate: _endDate!,
      notified: _notify,
      reportable: _reportable,
      goalImageUrl: _selectedIconUrl,
      amount: currentAmount,
    );

    final provider = Provider.of<SavingGoalProvider>(context, listen: false);
    final success = await provider.updateGoal(widget.goal.id, request);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      await provider.loadGoals(false, forceRefresh: true);
      _showSnackBar("Cập nhật thành công!", isError: false);
      Navigator.of(context).pop(true);
    } else {
      _showSnackBar(provider.errorMessage ?? "Lỗi khi lưu", isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: const Text("Edit Saving Goal",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
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
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.greenAccent.withOpacity(0.5), width: 2),
                        ),
                        child: IconHelper.buildCircleAvatar(
                          iconUrl: _selectedIconUrl,
                          radius: 30,
                          backgroundColor: const Color(0xFF1C1C1E),
                        ),
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
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
                    decoration: const InputDecoration(
                      labelText: "Goal Name",
                      labelStyle: TextStyle(color: Colors.grey, fontSize: 14),
                      border: InputBorder.none,
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
                  icon: Icons.track_changes,
                  iconColor: Colors.greenAccent,
                ),
                const Divider(height: 1, color: Colors.white10, indent: 40),
                _buildTextField(
                  controller: _currentController,
                  label: "Current Balance",
                  icon: Icons.account_balance_wallet,
                  iconColor: Colors.blueAccent,
                  enabled: true, // GIỮ NGUYÊN UI NHƯNG CHO PHÉP SỬA
                ),
                const Divider(height: 1, color: Colors.white10, indent: 40),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.currency_exchange, color: Colors.orangeAccent, size: 22),
                  title: const Text("Currency", style: TextStyle(color: Colors.grey, fontSize: 14)),
                  trailing: Text(_currency, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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
                  title: const Text("Target Date", style: TextStyle(color: Colors.grey, fontSize: 14)),
                  subtitle: Text(
                    DateFormat('MMMM dd, yyyy').format(_endDate!),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                ),
                const Divider(height: 1, color: Colors.white10, indent: 40),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.notifications_active_outlined, color: Colors.purpleAccent, size: 22),
                  title: const Text("Smart Notification", style: TextStyle(color: Colors.white, fontSize: 15)),
                  value: _notify,
                  activeColor: Colors.purpleAccent,
                  onChanged: (val) => setState(() => _notify = val),
                ),
                const Divider(height: 1, color: Colors.white10, indent: 40),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.insights_rounded, color: Colors.tealAccent, size: 22),
                  title: const Text("Show in Reports", style: TextStyle(color: Colors.white, fontSize: 15)),
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
    decoration: BoxDecoration(
      color: const Color(0xFF1C1C1E),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withOpacity(0.05)),
    ),
    child: child,
  );

  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon, Color iconColor = Colors.grey, bool enabled = true}) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(color: enabled ? Colors.white : Colors.grey),
      decoration: InputDecoration(
        icon: Icon(icon, color: iconColor, size: 22),
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        border: InputBorder.none,
      ),
    );
  }

  void _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: Colors.greenAccent, onPrimary: Colors.black, surface: Color(0xFF1C1C1E)),
        ),
        child: child!,
      ),
    );
    if (date != null) setState(() => _endDate = date);
  }
}
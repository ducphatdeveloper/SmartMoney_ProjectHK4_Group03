import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smart_money/core/helpers/icon_helper.dart';

import '../providers/saving_goal_provider.dart';
import '../models/saving_goal_request.dart';
import '../../category/models/icon_dto.dart';
import 'package:smart_money/modules/category/screens/icon_picker_screen.dart';

class AddSavingGoalScreen extends StatefulWidget {
  const AddSavingGoalScreen({super.key});

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

  /// Default Icon from Cloud
  String? _selectedIconUrl = "https://res.cloudinary.com/drd2hsocc/image/upload/v1774385006/icon_basic_wallet.png";

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _initialController.dispose();
    super.dispose();
  }

  // ===============================
  // 🎯 STRICT VALIDATION LOGIC
  // ===============================
  String? _validateData() {
    final name = _nameController.text.trim();
    final targetStr = _targetController.text.trim();
    final initialStr = _initialController.text.trim();

    if (name.isEmpty) return "Please enter a goal name";
    if (targetStr.isEmpty) return "Please enter your target amount";

    final targetAmount = double.tryParse(targetStr);
    // Requirement: Must be > 1000
    if (targetAmount == null || targetAmount < 1000) {
      return "Target amount must be greater than 1,000";
    }

    final initialAmount = double.tryParse(initialStr) ?? 0;
    if (initialAmount < 0) {
      return "Initial amount cannot be negative";
    }
    // Requirement: Initial cannot be greater than Target
    if (initialAmount > targetAmount) {
      return "Initial amount cannot exceed target amount";
    }

    if (_endDate == null) return "Please select a target date";

    // Safety check for past dates
    if (_endDate!.isBefore(DateTime.now().subtract(const Duration(days: 1)))) {
      return "Target date cannot be in the past";
    }

    return null;
  }

  void _openIconPicker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const IconPickerScreen(),
      ),
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
    final double initialAmount = double.tryParse(_initialController.text.trim()) ?? 0;

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
      await provider.loadGoals();
      _showSnackBar("Goal created successfully!", isError: false);
      Navigator.of(context).pop(true);
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
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        title: const Text("Create Saving Goal",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _handleSave,
            child: _isSaving
                ? const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.greenAccent),
            )
                : const Text("SAVE",
                style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildFieldWrapper(
            child: Row(
              children: [
                // Thay thế đoạn code hiển thị Icon cũ bằng đoạn này:
                GestureDetector(
                  onTap: _openIconPicker,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      // Viền bao ngoài icon
                      Container(
                        padding: const EdgeInsets.all(3), // Độ dày của viền
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.greenAccent.withOpacity(0.5), // Màu sắc viền
                            width: 2,
                          ),
                        ),
                        child: IconHelper.buildCircleAvatar(
                          iconUrl: _selectedIconUrl,
                          radius: 30,
                          backgroundColor: const Color(0xFF1C1C1E),
                        ),
                      ),
                      // Nút Edit (bút chì)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 2), // Viền để tách biệt nút edit
                        ),
                        child: const Icon(Icons.edit_rounded, size: 12, color: Colors.white),
                      )
                    ],
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    autofocus: true,
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
                  label: "Target Amount > 1,000",
                  hint: "e.g. 5000000",
                  icon: Icons.track_changes,
                  iconColor: Colors.greenAccent,
                ),
                const Divider(height: 1, color: Colors.white10, indent: 40),
                _buildTextField(
                  controller: _initialController,
                  label: "Initial Amount cannot be negative",
                  hint: "0",
                  icon: Icons.account_balance_wallet,
                  iconColor: Colors.blueAccent,
                ),
                const Divider(height: 1, color: Colors.white10, indent: 40),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.currency_exchange, color: Colors.orangeAccent, size: 22),
                  title: const Text("Currency", style: TextStyle(color: Colors.grey, fontSize: 14)),
                  trailing: const Text(
                    "VND (₫)",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
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

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(text,
          style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
    );
  }

  Widget _buildFieldWrapper({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: child,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    required IconData icon,
    Color iconColor = Colors.grey,
  }) {
    return TextField(
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
  }

  void _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ?? now.add(const Duration(days: 30)),
      firstDate: now, // User cannot pick past dates
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
                primary: Colors.greenAccent,
                onPrimary: Colors.black,
                surface: Color(0xFF1C1C1E)
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) setState(() => _endDate = date);
  }
}
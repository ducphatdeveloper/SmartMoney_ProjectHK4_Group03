import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/helpers/icon_helper.dart';

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

  // 🔥 GÁN LUÔN ICON MẶC ĐỊNH Ở ĐÂY
  // Thay URL này bằng icon "quốc dân" trong hệ thống của bạn
  String? _selectedIconUrl = "https://res.cloudinary.com/drd2hsocc/image/upload/v1774385006/icon_basic_wallet.png";
  String? _selectedIconFileName;

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _initialController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    final targetStr = _targetController.text.trim();

    if (name.isEmpty || targetStr.isEmpty || _endDate == null) {
      _showSnackBar("Please fill in all required fields", isError: true);
      return;
    }

    final double targetAmount = double.tryParse(targetStr) ?? 0;
    final double initialAmount = double.tryParse(_initialController.text) ?? 0;

    final request = SavingGoalRequest(
      goalName: name,
      targetAmount: targetAmount,
      initialAmount: initialAmount,
      currencyCode: _currency,
      endDate: _endDate!,
      notified: _notify,
      reportable: _reportable,
      // Nếu user không đổi thì dùng icon mặc định ở trên
      goalImageUrl: _selectedIconFileName ?? _selectedIconUrl,
      amount: initialAmount,
    );

    final provider = Provider.of<SavingGoalProvider>(context, listen: false);
    final success = await provider.createGoal(request);

    if (success && mounted) {
      _showSnackBar("Goal created successfully!", isError: false);
      Navigator.of(context).pop(true);
    } else if (mounted) {
      _showSnackBar(provider.errorMessage ?? "API Connection Error");
    }
  }

  void _openIconPicker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IconPickerScreen(
          currentIconFileName: _selectedIconFileName,
        ),
      ),
    );

    if (result != null && result is IconDto && mounted) {
      setState(() {
        _selectedIconUrl = result.url;
        _selectedIconFileName = result.fileName;
      });
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<SavingGoalProvider>().isLoading;

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
            onPressed: isLoading ? null : _handleSave,
            child: isLoading
                ? const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green),
            )
                : const Text("SAVE",
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ================= ICON + NAME =================
          _buildFieldWrapper(
            child: Row(
              children: [
                GestureDetector(
                  onTap: _openIconPicker,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      // Hiển thị icon đã có sẵn ngay từ đầu
                      IconHelper.buildCircleAvatar(
                        iconUrl: _selectedIconUrl,
                        radius: 28,
                        backgroundColor: Colors.orange.withOpacity(0.1),
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                        child: const Icon(Icons.edit, size: 10, color: Colors.white),
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
                  icon: Icons.track_changes,
                  iconColor: Colors.greenAccent,
                ),
                const Divider(height: 1, color: Colors.white10, indent: 40),
                _buildTextField(
                  controller: _initialController,
                  label: "Initial Amount (Optional)",
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
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        border: InputBorder.none,
      ),
    );
  }

  void _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
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
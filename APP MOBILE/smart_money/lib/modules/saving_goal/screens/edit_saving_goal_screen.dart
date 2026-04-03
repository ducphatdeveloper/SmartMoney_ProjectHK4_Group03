import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smart_money/core/helpers/icon_helper.dart';

import '../providers/saving_goal_provider.dart';
import '../models/saving_goal_request.dart';
import '../models/saving_goal_response.dart';
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
  bool _notified = true;
  bool _reportable = true;
  bool _isSaving = false;
  String? _selectedIconUrl;
  late String _currencyCode;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.goal.goalName);
    _targetController = TextEditingController(
        text: widget.goal.targetAmount.toInt().toString());
    _currentController = TextEditingController(
        text: widget.goal.currentAmount.toInt().toString());

    _currencyCode = widget.goal.currencyCode ?? 'VND';
    _endDate = widget.goal.endDate;
    _notified = widget.goal.notified ?? true;
    _reportable = widget.goal.reportable ?? true;
    _selectedIconUrl = widget.goal.imageUrl;
  }

  void _openIconPicker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const IconPickerScreen()),
    );
    if (result != null && mounted) {
      setState(() => _selectedIconUrl = result.url);
    }
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    final target = double.tryParse(_targetController.text) ?? 0;
    final current = double.tryParse(_currentController.text) ?? 0;

    if (name.isEmpty || target <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid name and target")),
      );
      return;
    }

    setState(() => _isSaving = true);

    final request = SavingGoalRequest(
      goalName: name,
      targetAmount: target,
      initialAmount: current,
      currencyCode: _currencyCode,
      endDate: _endDate!,
      notified: _notified,
      reportable: _reportable,
      goalImageUrl: _selectedIconUrl,
    );

    final provider = context.read<SavingGoalProvider>();
    final success = await provider.updateGoal(widget.goal.id, request);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      provider.loadGoals();
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        centerTitle: true,
        title: const Text("Edit Goal", style: TextStyle(color: Colors.white)),
        leadingWidth: 80,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _handleSave,
            child: _isSaving
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.green,
              ),
            )
                : const Text(
              "SAVE",
              style: TextStyle(
                  color: Colors.green, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// --- SECTION 1: CƠ BẢN (NAME & ICON) ---
            _buildCard([
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _openIconPicker,
                      child: IconHelper.buildCircleAvatar(
                        iconUrl: _selectedIconUrl,
                        radius: 24,
                        backgroundColor: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          labelText: "Goal Name",
                          labelStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ]),

            const SizedBox(height: 16),

            /// --- SECTION 2: TÀI CHÍNH & THỜI GIAN ---
            _buildCard([
              _buildRow(Icons.track_changes, "Target Amount", _targetController,
                  isNumber: true, iconColor: Colors.greenAccent),
              _buildDivider(),
              _buildRow(Icons.account_balance_wallet, "Current Balance",
                  _currentController,
                  isNumber: true, iconColor: Colors.blueAccent),
              _buildDivider(),

              /// 🔥 HIỂN THỊ CURRENCY (READ-ONLY)
              _buildReadOnlyRow(Icons.currency_exchange, "Currency", "VIET NAM DONG",
                  iconColor: Colors.orangeAccent),

              _buildDivider(),
              ListTile(
                leading: const Icon(Icons.calendar_today,
                    color: Colors.redAccent, size: 22),
                title: const Text("End Date",
                    style: TextStyle(color: Colors.grey, fontSize: 14)),
                subtitle: Text(DateFormat('MMMM dd, yyyy').format(_endDate!),
                    style: const TextStyle(color: Colors.white, fontSize: 16)),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () async {
                  final p = await showDatePicker(
                    context: context,
                    initialDate: _endDate!,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (p != null) setState(() => _endDate = p);
                },
              ),
            ]),

            const SizedBox(height: 16),

            /// --- SECTION 3: CÀI ĐẶT THÊM ---
            _buildCard([
              SwitchListTile(
                secondary: const Icon(Icons.notifications_active_outlined,
                    color: Colors.purpleAccent),
                title: const Text("Smart Notification",
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text("Remind me to save regularly",
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                value: _notified,
                activeColor: Colors.purpleAccent,
                onChanged: (val) => setState(() => _notified = val),
              ),
              _buildDivider(),
              SwitchListTile(
                secondary: const Icon(Icons.insights_rounded,
                    color: Colors.tealAccent),
                title: const Text("Show in Reports",
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text("Include this goal in analytics",
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                value: _reportable,
                activeColor: Colors.greenAccent,
                onChanged: (val) => setState(() => _reportable = val),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(20)),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() =>
      const Divider(height: 1, indent: 55, color: Color(0xFF2C2C2E));

  Widget _buildRow(
      IconData icon, String label, TextEditingController controller,
      {bool isNumber = false, Color iconColor = Colors.grey}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType:
              isNumber ? TextInputType.number : TextInputType.text,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: const TextStyle(color: Colors.grey),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyRow(IconData icon, String label, String value,
      {Color iconColor = Colors.grey}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 4),
              Text(value,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}
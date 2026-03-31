import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/saving_goal_provider.dart';
import '../models/saving_goal_request.dart';
import '../models/saving_goal_response.dart';

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
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.goal.goalName);
    _targetController = TextEditingController(text: widget.goal.targetAmount.toInt().toString());
    _currentController = TextEditingController(text: widget.goal.currentAmount.toInt().toString());
    _endDate = widget.goal.endDate;
    _notified = widget.goal.notified ?? true;
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    final target = double.tryParse(_targetController.text) ?? 0;
    final current = double.tryParse(_currentController.text) ?? 0;

    if (name.isEmpty || target <= 0) return;

    setState(() => _isSaving = true);

    final request = SavingGoalRequest(
      goalName: name,
      targetAmount: target,
      initialAmount: current,
      currencyCode: widget.goal.currencyCode ?? 'VND',
      endDate: _endDate!,
      notified: _notified,
      reportable: true,
    );

    final provider = context.read<SavingGoalProvider>();
    final success = await provider.updateGoal(widget.goal.id, request);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      provider.loadGoals();
      int count = 0;
      Navigator.of(context).popUntil((_) => count++ >= 2);
      _showSnackBar("Updated successfully!");
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
    );
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
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel", style: TextStyle(color: Colors.redAccent, fontSize: 15)),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _handleSave,
            child: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green))
                : const Text("SAVE", style: TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              _buildRow(Icons.edit, "Goal Name", _nameController, iconColor: Colors.orange),
              const Divider(height: 1, color: Color(0xFF2C2C2E)),
              _buildRow(Icons.track_changes, "Target Amount", _targetController, isNumber: true, iconColor: Colors.green),
              const Divider(height: 1, color: Color(0xFF2C2C2E)),
              _buildRow(Icons.wallet, "Current Balance", _currentController, isNumber: true, iconColor: Colors.blue),
              const Divider(height: 1, color: Color(0xFF2C2C2E)),
              ListTile(
                leading: const Icon(Icons.calendar_today, color: Colors.grey, size: 22),
                title: Text(DateFormat('MMMM dd, yyyy').format(_endDate!), style: const TextStyle(color: Colors.white)),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () async {
                  final p = await showDatePicker(context: context, initialDate: _endDate!, firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (p != null) setState(() => _endDate = p);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(IconData icon, String label, TextEditingController controller, {bool isNumber = false, Color iconColor = Colors.grey}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: isNumber ? TextInputType.number : TextInputType.text,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.grey), border: InputBorder.none),
            ),
          ),
        ],
      ),
    );
  }
}
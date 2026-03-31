import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/saving_goal_provider.dart';
import '../models/saving_goal_request.dart';

class AddSavingGoalScreen extends StatefulWidget {
  const AddSavingGoalScreen({super.key});

  @override
  State<AddSavingGoalScreen> createState() => _AddSavingGoalScreenState();
}

class _AddSavingGoalScreenState extends State<AddSavingGoalScreen> {
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  final _initialController = TextEditingController();

  String _currency = "VND";
  bool _notify = true;
  DateTime? _endDate;
  final IconData _selectedIcon = Icons.savings;

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
    );

    final provider = Provider.of<SavingGoalProvider>(context, listen: false);
    final success = await provider.createGoal(request);

    if (success && mounted) {
      _showSnackBar("Goal created successfully!", isError: false);
      Navigator.of(context).pop();
      Navigator.of(context).pop(true);
    } else if (mounted) {
      _showSnackBar(provider.errorMessage ?? "API Connection Error");
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

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<SavingGoalProvider>().isLoading;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text("Create Saving Goal", style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: isLoading ? null : _handleSave,
            child: isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green))
                : const Text("SAVE", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildFieldWrapper(
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.orange.withOpacity(0.1),
                  child: Icon(_selectedIcon, color: Colors.orange),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                        hintText: "Goal Name",
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.grey)
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          _buildFieldWrapper(
            child: TextField(
              controller: _targetController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                  labelText: "Target Amount",
                  labelStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none
              ),
            ),
          ),
          const SizedBox(height: 15),
          _buildFieldWrapper(
            child: TextField(
              controller: _initialController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                  labelText: "Initial Amount (Optional)",
                  labelStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none
              ),
            ),
          ),
          const SizedBox(height: 15),
          _buildFieldWrapper(
            child: ListTile(
              onTap: _pickDate,
              contentPadding: EdgeInsets.zero,
              title: Text(
                _endDate == null ? "Target Date" : DateFormat('MMMM dd, yyyy').format(_endDate!),
                style: TextStyle(color: _endDate == null ? Colors.grey : Colors.white),
              ),
              trailing: const Icon(Icons.calendar_today, color: Colors.grey, size: 20),
            ),
          ),
          const SizedBox(height: 15),
          _buildFieldWrapper(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("Notifications", style: TextStyle(color: Colors.white)),
              value: _notify,
              activeColor: Colors.green,
              onChanged: (val) => setState(() => _notify = val),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldWrapper({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(12)
      ),
      child: child,
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
            colorScheme: const ColorScheme.dark(primary: Colors.green),
          ),
          child: child!,
        );
      },
    );
    if (date != null) setState(() => _endDate = date);
  }
}
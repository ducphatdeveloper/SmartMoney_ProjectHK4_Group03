import 'package:flutter/material.dart';
import 'package:smart_money/modules/Transfer_transaction/widgets/amout_input.dart';
import 'package:smart_money/modules/Transfer_transaction/widgets/setting_title.dart';
import '../widgets/transaction_tab_switch.dart';
import '../widgets/date_switcher.dart';
import '../widgets/bottom_save_button.dart';

class AddTransactionView extends StatefulWidget {
  final VoidCallback? onCancel; // 👈 thêm
  final VoidCallback? onSave;   // 👈 thêm

  const AddTransactionView({
    super.key,
    this.onCancel,
    this.onSave,
  });

  @override
  State<AddTransactionView> createState() => _AddTransactionViewState();
}

class _AddTransactionViewState extends State<AddTransactionView> {
  TransactionTab tab = TransactionTab.expense;
  final amountCtrl = TextEditingController();
  DateTime date = DateTime.now();
  bool excludeReport = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: TextButton(
          onPressed: () {
            amountCtrl.clear(); // reset form
            widget.onCancel?.call(); // 👈 quay về Home
          },
          child: const Text("Cancel"),
        ),
        title: const Text("Add Transaction"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TransactionTabSwitch(
              tab: tab,
              onChanged: (v) => setState(() => tab = v),
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SettingTile(
                  icon: Icons.account_balance_wallet,
                  title: "Total",
                ),

                const SizedBox(height: 12),
                AmountInput(controller: amountCtrl),

                const Divider(height: 32),

                const SettingTile(icon: Icons.circle, title: "Select category"),
                const SettingTile(icon: Icons.notes, title: "Note"),

                const SizedBox(height: 16),
                DateSwitcher(
                  date: date,
                  onPrevious: () {},
                  onNext: () {},
                ),

                const Divider(height: 32),

                const SettingTile(icon: Icons.people, title: "With"),
                const SettingTile(icon: Icons.location_on, title: "Set location"),
                const SettingTile(icon: Icons.event, title: "Select event"),
                const SettingTile(icon: Icons.alarm, title: "Set reminder"),

                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.image, color: Colors.green),
                  label: const Text(
                    "Add Image",
                    style: TextStyle(color: Colors.green),
                  ),
                ),

                SwitchListTile(
                  value: excludeReport,
                  onChanged: (v) => setState(() => excludeReport = v),
                  title: const Text("Exclude from reports"),
                ),
              ],
            ),
          ),

          BottomSaveButton(
            onSave: () {
              amountCtrl.clear();
              widget.onSave?.call(); // 👈 save xong về Home
            },
          ),
        ],
      ),
    );
  }
}
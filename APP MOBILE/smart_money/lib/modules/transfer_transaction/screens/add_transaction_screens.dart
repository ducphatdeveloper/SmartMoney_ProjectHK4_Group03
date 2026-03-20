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
          child: const Text("Huỷ"),
        ),
        title: const Text("Thêm Giao Dịch"),
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
                  title: "Tổng Cộng",
                ),

                const SizedBox(height: 12),
                AmountInput(controller: amountCtrl),

                const Divider(height: 32),

                const SettingTile(icon: Icons.circle, title: "Chọn nhóm"),
                const SettingTile(icon: Icons.notes, title: "Ghi chú"),

                const SizedBox(height: 16),
                DateSwitcher(
                  date: date,
                  onPrevious: () {},
                  onNext: () {},
                ),

                const Divider(height: 32),

                const SettingTile(icon: Icons.people, title: "Với"),
                const SettingTile(icon: Icons.location_on, title: "Đặt vị trí"),
                const SettingTile(icon: Icons.event, title: "Chọn sự kiện"),
                const SettingTile(icon: Icons.alarm, title: "Đặt nhắc nhở"),

                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.image, color: Colors.green),
                  label: const Text(
                    "Thêm Hình Ảnh",
                    style: TextStyle(color: Colors.green),
                  ),
                ),

                SwitchListTile(
                  value: excludeReport,
                  onChanged: (v) => setState(() => excludeReport = v),
                  title: const Text("Không tính vào báo cáo"),
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
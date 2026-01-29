import 'package:flutter/material.dart';
import 'package:money_lover/event/screen/event_screen.dart';
import 'package:money_lover/wallet/screens/wallet_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        centerTitle: true,
        title: const Text("Tài khoản"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _profileCard(),
          const SizedBox(height: 24),

          _item(
            Icons.account_balance_wallet,
            "Ví của tôi",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WalletScreen()),
              );
            },
          ),
          _item(Icons.group, "Nhóm"),
          _item(
            Icons.event,
            "Sự kiện",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EventScreen()),
              );
            },
          ),
          _item(Icons.autorenew, "Giao dịch định kỳ"),
          _item(Icons.receipt_long, "Hóa đơn"),
          _item(Icons.request_page, "Sổ nợ"),

          const SizedBox(height: 16),
          _section("Khác"),
          _item(Icons.build, "Công cụ"),
          _item(Icons.upload_file, "Xuất dữ liệu tới Google Trang tính"),
          _item(Icons.settings, "Cài đặt"),
        ],
      ),
    );
  }

  // ===== Widgets =====

  Widget _profileCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: const [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.green,
            child: Icon(Icons.person, size: 32, color: Colors.white),
          ),
          SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Minh Nhất",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text("Free account", style: TextStyle(color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 14, color: Colors.grey),
      ),
    );
  }

  Widget _item(IconData icon, String title, {VoidCallback? onTap}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.white),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap ?? () {},
    );
  }
}

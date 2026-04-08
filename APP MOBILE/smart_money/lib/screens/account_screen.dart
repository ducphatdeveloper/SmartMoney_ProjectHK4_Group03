import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../modules/category/screens/category_list_screen.dart';
import '../../modules/planned/screens/recurring_screen.dart';
import '../../modules/planned/screens/bill_screen.dart';
import '../../modules/event/screens/event_screen.dart';
import '../../modules/saving_goal/screens/saving_goal_list_screen.dart';
import 'package:smart_money/modules/saving_goal/screens/saving_goal_list_view.dart';
import '../../modules/wallet/screens/wallet_screen.dart';
import '../../modules/debt/screens/debt_list_screen.dart';
import '../modules/contact/screens/contact_support_screen.dart';
import 'account_management_screen.dart';
import '../../modules/auth/providers/auth_provider.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  @override
  void initState() {
    super.initState();
    // Update profile data when entering screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().getProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    // Display fullname if available, otherwise email or "User"
    final String displayName = (user?.fullname != null && user!.fullname!.trim().isNotEmpty)
        ? user.fullname!
        : (user?.accEmail ?? "User");

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        centerTitle: true,
        title: const Text("Account"),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Allow user to pull down to refresh profile data
          await authProvider.getProfile();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _profileCard(displayName, user?.accEmail ?? ""),
            const SizedBox(height: 24),

            _item(
              Icons.manage_accounts,
              "Account Management",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AccountManagementScreen()),
                );
              },
            ),

          _item(
            Icons.account_balance_wallet,
            "My Wallets",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WalletListView()),
              );
            },
          ),

          _item(
            Icons.account_balance_wallet,
            "My Savings",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SavingGoalListScreen()),
              );
            },
          ),

          _item(Icons.group, "Categories" ,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CategoryListScreen()),
                );
              },
            ),

            _item(
              Icons.event,
              "Events",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EventScreen()),
                );
              },
            ),
            _item(
              Icons.autorenew,
              "Recurring Transactions",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RecurringScreen()),
                );
              },
            ),
            _item(
              Icons.receipt_long,
              "Bills",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BillScreen()),
                );
              },
            ),
            _item(
              Icons.request_page,
              "Debts",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DebtListScreen()),
                );
              },
            ),

            const SizedBox(height: 16),
            _section("Other"),
            _item(
              Icons.support_agent,
              "Customer Support",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ContactSupportScreen()),
                );
              },
            ),
            _item(Icons.build, "Tools"),
            _item(Icons.upload_file, "Export to Google Sheets"),
            _item(Icons.settings, "Settings"),
          ],
        ),
      ),
    );
  }

  // ===== Widgets =====

  Widget _profileCard(String name, String email) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: Colors.green,
            child: Icon(Icons.person, size: 32, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(email.isNotEmpty ? email : "Free account", style: const TextStyle(color: Colors.grey)),
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

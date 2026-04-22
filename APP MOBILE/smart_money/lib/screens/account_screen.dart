import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../modules/category/screens/category_list_screen.dart';
import '../../modules/planned/screens/recurring_screen.dart';
import '../../modules/planned/screens/bill_screen.dart';
import '../../modules/event/screens/event_screen.dart';
import '../../modules/saving_goal/screens/saving_goal_list_screen.dart';
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
  bool _canBiometric = false;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.isLoggedIn) {
        authProvider.getProfile();
      }
      _checkBiometricSupport();
    });
  }

  Future<void> _checkBiometricSupport() async {
    final authProvider = context.read<AuthProvider>();
    final canBio = await authProvider.canUseBiometric();
    final isEnabled = await authProvider.isBiometricEnabled();
    if (mounted) {
      setState(() {
        _canBiometric = canBio;
        _biometricEnabled = isEnabled;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    final isLoggedIn = authProvider.isLoggedIn;

    final String displayName = isLoggedIn 
        ? ((user?.fullname != null && user!.fullname!.trim().isNotEmpty) ? user.fullname! : (user?.accEmail ?? "User"))
        : "Guest User";

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        centerTitle: true,
        title: const Text("Account"),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (isLoggedIn) {
            await authProvider.getProfile();
          }
          await _checkBiometricSupport();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _profileCard(displayName, isLoggedIn ? (user?.accEmail ?? "") : "Sign in to protect your data", isLoggedIn, user?.avatarUrl),
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
            Icons.savings,
            "My Savings",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SavingGoalListScreen()),
              );
            },
          ),

          _item(Icons.category, "Categories" ,
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
            _section("Security"),
            if (_canBiometric)
              SwitchListTile(
                title: const Text("Biometric Login", style: TextStyle(color: Colors.white)),
                subtitle: const Text("Fingerprint / FaceID", style: TextStyle(color: Colors.grey, fontSize: 12)),
                secondary: const Icon(Icons.fingerprint, color: Colors.white),
                value: _biometricEnabled,
                activeColor: Colors.green,
                onChanged: (bool value) async {
                  await authProvider.toggleBiometric(value);
                  setState(() {
                    _biometricEnabled = value;
                  });
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
          ],
        ),
      ),
    );
  }

  Widget _profileCard(String name, String subtitle, bool isLoggedIn, String? avatarUrl) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.green,
            backgroundImage: (isLoggedIn && avatarUrl != null && !avatarUrl.contains('svg')) 
                ? NetworkImage(avatarUrl) 
                : null,
            child: (isLoggedIn && (avatarUrl == null || avatarUrl.contains('svg')))
                ? Text(name.isNotEmpty ? name[0].toUpperCase() : "U", style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold))
                : (!isLoggedIn ? const Icon(Icons.person, size: 32, color: Colors.white) : null),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
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

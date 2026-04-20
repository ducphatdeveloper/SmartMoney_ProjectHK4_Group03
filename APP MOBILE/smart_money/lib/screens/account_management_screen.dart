import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../modules/auth/providers/auth_provider.dart';

class AccountManagementScreen extends StatefulWidget {
  const AccountManagementScreen({super.key});

  @override
  State<AccountManagementScreen> createState() => _AccountManagementScreenState();
}

class _AccountManagementScreenState extends State<AccountManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.read<AuthProvider>().isLoggedIn) {
        context.read<AuthProvider>().getProfile();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isLoggedIn = authProvider.isLoggedIn;
    final user = authProvider.currentUser;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Account Management"),
        backgroundColor: Colors.black,
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (isLoggedIn) {
            await authProvider.getProfile();
          }
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (authProvider.isLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: LinearProgressIndicator(backgroundColor: Colors.black, color: Colors.purple),
              ),
              
            // ===== PROFILE CARD =====
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: isLoggedIn ? () => _pickAndUploadImage(context, authProvider) : null,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: Colors.purple,
                          backgroundImage: (isLoggedIn && user?.avatarUrl != null && !user!.avatarUrl!.contains('svg')) 
                              ? NetworkImage(user!.avatarUrl!) 
                              : null,
                          child: (isLoggedIn && (user?.avatarUrl == null || user!.avatarUrl!.contains('svg')))
                              ? Text(
                                  (user?.fullname != null && user!.fullname!.isNotEmpty)
                                      ? user.fullname![0].toUpperCase()
                                      : "U", 
                                  style: const TextStyle(fontSize: 28, color: Colors.white))
                              : (!isLoggedIn ? const Icon(Icons.person, size: 40, color: Colors.white) : null),
                        ),
                        if (isLoggedIn)
                          const Positioned(
                            right: 0,
                            bottom: 0,
                            child: CircleAvatar(radius: 10, backgroundColor: Colors.green, child: Icon(Icons.camera_alt, size: 12, color: Colors.white)),
                          )
                      ],
                    ),
                  ),

                const SizedBox(height: 12),

                if (isLoggedIn)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade700,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "FREE ACCOUNT",
                      style: TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ),

                const SizedBox(height: 12),

                Text(
                  isLoggedIn ? (user?.fullname ?? "No name set") : "Guest User",
                  style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 4),

                Text(
                  isLoggedIn ? (user?.accEmail ?? "") : "Sign in to sync your data",
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          if (isLoggedIn) ...[
            _button(
              title: "Edit Profile",
              color: Colors.blueAccent,
              onTap: () => context.push('/edit-profile'),
            ),
            const SizedBox(height: 12),
            _button(
              title: "Change Password",
              color: Colors.green,
              onTap: () async {
                final email = user?.accEmail;
                if (email != null) {
                  context.push('/reset-password', extra: email);
                }
              },
            ),
            const SizedBox(height: 12),
            _button(
              title: "Logout",
              color: Colors.red,
              onTap: () => _confirmLogout(context, authProvider),
            ),
          ] else ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Text(
                "You are currently not logged in. Login to access all features and protect your data.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),
            _button(
              title: "Login",
              color: Colors.greenAccent,
              onTap: () => context.go('/login'),
            ),
            const SizedBox(height: 12),
            _button(
              title: "Register",
              color: Colors.blueAccent,
              onTap: () => context.go('/register'),
            ),
          ],
        ],
      ),
    )
    );
  }

  Widget _button({
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(30),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
            onPressed: () async {
              Navigator.pop(context);
              await authProvider.logout(context);
              // Chuyển hướng thẳng tới /login sau khi logout
              if (context.mounted) {
                context.go("/login");
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadImage(BuildContext context, AuthProvider auth) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await showModalBottomSheet<XFile?>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.white),
                title: const Text('Photo Library', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  final XFile? file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                  if (context.mounted) Navigator.pop(context, file);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.white),
                title: const Text('Take New Photo', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  final XFile? file = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
                  if (context.mounted) Navigator.pop(context, file);
                },
              ),
            ],
          ),
        );
      },
    );

    if (image != null) {
      final String? newUrl = await auth.updateAvatar(image.path);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(newUrl != null ? "Profile picture updated successfully!" : "Update failed.")),
        );
      }
    }
  }
}

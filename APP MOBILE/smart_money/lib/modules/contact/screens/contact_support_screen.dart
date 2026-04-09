import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/contact_request_models.dart';
import '../providers/contact_provider.dart';

class ContactSupportScreen extends StatefulWidget {
  const ContactSupportScreen({super.key});

  @override
  State<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends State<ContactSupportScreen> {
  final _formKey = GlobalKey<FormState>();
  ContactRequestType _selectedType = ContactRequestType.GENERAL;
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _fullnameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.isLoggedIn) {
        final user = authProvider.currentUser;
        if (user != null) {
          _fullnameController.text = user.fullname ?? "";
          _phoneController.text = user.accPhone ?? "";
          _emailController.text = user.accEmail ?? "";
        }
        context.read<ContactProvider>().fetchMyRequests();
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _fullnameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contactProvider = context.watch<ContactProvider>();
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Customer Support"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Submit New Support Request",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  DropdownButtonFormField<ContactRequestType>(
                    value: _selectedType,
                    decoration: const InputDecoration(
                      labelText: "Request Type",
                      border: OutlineInputBorder(),
                    ),
                    items: ContactRequestType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(_getRequestTypeLabel(type)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedType = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _fullnameController,
                    decoration: const InputDecoration(
                      labelText: "Full Name",
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? "Please enter your name" : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: "Phone Number",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: "Email Address",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: "Subject",
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? "Please enter a subject" : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: "Detailed Content",
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? "Please enter the content" : null,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: contactProvider.isLoading
                          ? null
                          : () async {
                              if (!_formKey.currentState!.validate()) return;
                              
                              if (_phoneController.text.isEmpty && _emailController.text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Please provide Phone or Email for contact")),
                                );
                                return;
                              }

                              final request = ContactRequestCreateRequest(
                                requestType: _selectedType,
                                title: _titleController.text,
                                requestDescription: _descriptionController.text,
                                fullname: _fullnameController.text,
                                contactPhone: _phoneController.text.isEmpty ? null : _phoneController.text,
                                contactEmail: _emailController.text.isEmpty ? null : _emailController.text,
                              );

                              final success = await contactProvider.createRequest(request);
                              if (success) {
                                _titleController.clear();
                                _descriptionController.clear();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Request submitted successfully!")),
                                );
                                if (authProvider.isLoggedIn) {
                                  context.read<ContactProvider>().fetchMyRequests();
                                }
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Submission failed")),
                                );
                              }
                            },
                      child: contactProvider.isLoading
                          ? const CircularProgressIndicator()
                          : const Text("Submit Request"),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              "Need Immediate Help?",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final Uri url = Uri(scheme: 'tel', path: '0373553880');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Unable to make a call")),
                    );
                  }
                },
                icon: const Icon(Icons.phone),
                label: const Text("Call us on our hotline."),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),

            if (authProvider.isLoggedIn) ...[
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                "Your Request History",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              contactProvider.isLoading && contactProvider.myRequests.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : contactProvider.myRequests.isEmpty
                      ? const Center(child: Text("No history data available."))
                      : Builder(
                          builder: (context) {
                            // Sắp xếp yêu cầu theo ngày tạo mới nhất lên đầu
                            final sortedRequests = List.from(contactProvider.myRequests)
                              ..sort((a, b) => DateTime.parse(b.createdAt).compareTo(DateTime.parse(a.createdAt)));

                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: sortedRequests.length,
                              separatorBuilder: (_, __) => const Divider(),
                              itemBuilder: (context, index) {
                                final req = sortedRequests[index];
                                final typeLabel = _getRequestTypeLabel(
                                    ContactRequestType.values.firstWhere((e) => e.name == req.requestType, orElse: () => ContactRequestType.GENERAL)
                                );

                                return ListTile(
                                  title: Text(req.title),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Type: $typeLabel"),
                                      Text(req.requestDescription),
                                      if (req.adminNote != null)
                                        Text("Admin Note: ${req.adminNote}", style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.blueGrey)),
                                      const SizedBox(height: 4),
                                      Text("Status: ${req.requestStatus}", style: TextStyle(
                                        color: _getStatusColor(req.requestStatus),
                                        fontWeight: FontWeight.bold
                                      )),
                                    ],
                                  ),
                                  trailing: Text(req.createdAt.split('T')[0]),
                                );
                              },
                            );
                          },
                        ),
            ],
          ],
        ),
      ),
    );
  }

  String _getRequestTypeLabel(ContactRequestType type) {
    switch (type) {
      case ContactRequestType.ACCOUNT_LOCK: return "Account Lock Request";
      case ContactRequestType.ACCOUNT_UNLOCK: return "Account Unlock Request";
      case ContactRequestType.FORGOT_PASSWORD: return "Forgot Password";
      case ContactRequestType.EMERGENCY: return "Emergency (Hacked/Suspicious)";
      case ContactRequestType.BUG_REPORT: return "Bug Report";
      case ContactRequestType.DATA_RECOVERY: return "Data Recovery Request";
      case ContactRequestType.DATA_LOSS: return "Data Loss Report";
      case ContactRequestType.GENERAL: return "General Feedback/Question";
      case ContactRequestType.SUSPICIOUS_TX: return "Suspicious Transaction";
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PENDING': return Colors.orange;
      case 'PROCESSING': return Colors.blue;
      case 'APPROVED': return Colors.green;
      case 'REJECTED': return Colors.red;
      default: return Colors.grey;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../modules/auth/providers/auth_provider.dart';
import '../modules/auth/models/update_profile_request.dart';

class ProfileEditingScreen extends StatefulWidget {
  const ProfileEditingScreen({super.key});

  @override
  State<ProfileEditingScreen> createState() => _ProfileEditingScreenState();
}

class _ProfileEditingScreenState extends State<ProfileEditingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullnameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  
  String? _selectedGender;
  DateTime? _selectedDate;
  final List<String> _genders = ["Male", "Female", "Other"];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<AuthProvider>().getProfile();
      _fillData();
    });
  }

  void _fillData() {
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) {
      setState(() {
        _fullnameController.text = user.fullname ?? "";
        _phoneController.text = user.accPhone ?? "";
        _addressController.text = user.address ?? "";
        
        String? genderFromDb = user.gender;
        if (genderFromDb == "Nam") _selectedGender = "Male";
        else if (genderFromDb == "Nữ") _selectedGender = "Female";
        else if (genderFromDb == "Khác") _selectedGender = "Other";
        else _selectedGender = _genders.contains(genderFromDb) ? genderFromDb : null;
        
        if (user.dateofbirth != null) {
          _selectedDate = DateTime.tryParse(user.dateofbirth!);
        }
      });
    }
  }

  @override
  void dispose() {
    _fullnameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      String? genderToSave = _selectedGender;
      if (_selectedGender == "Male") genderToSave = "Nam";
      else if (_selectedGender == "Female") genderToSave = "Nữ";
      else if (_selectedGender == "Other") genderToSave = "Khác";

      final request = UpdateProfileRequest(
        fullname: _fullnameController.text,
        accPhone: _phoneController.text, // Thêm số điện thoại vào request
        address: _addressController.text,
        gender: genderToSave,
        dateofbirth: _selectedDate != null 
            ? DateFormat('yyyy-MM-dd').format(_selectedDate!) 
            : null,
      );

      final success = await context.read<AuthProvider>().updateProfile(request);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success ? "Update successful!" : "Update failed")),
        );
        if (success) Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Edit Profile"),
        backgroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTextField(
                _fullnameController, 
                "Full Name", 
                Icons.person,
                validator: (value) {
                  if (value == null || value.isEmpty) return "Please enter full name";
                  if (value.trim().length < 2) return "Name must be at least 2 characters";
                  return null;
                },
              ),
              _buildTextField(
                _phoneController, 
                "Phone Number", 
                Icons.phone, 
                enabled: true, // Đã bật cho phép chỉnh sửa
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) return "Please enter phone number";
                  if (!RegExp(r'^\d{10,11}$').hasMatch(value)) return "Invalid phone number (10-11 digits)";
                  return null;
                },
              ), 
              _buildTextField(_addressController, "Address", Icons.location_on, validator: null),
              
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                value: _selectedGender,
                dropdownColor: const Color(0xFF1C1C1E),
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration("Gender", Icons.wc),
                items: _genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                onChanged: (val) => setState(() => _selectedGender = val),
              ),

              const SizedBox(height: 16),

              InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: _inputDecoration("Date of Birth", Icons.cake),
                  child: Text(
                    _selectedDate == null 
                        ? "Select birth date" 
                        : DateFormat('MM/dd/yyyy').format(_selectedDate!),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: defaultTargetPlatform == TargetPlatform.android ? const StadiumBorder() : null,
                  ),
                  child: isLoading 
                      ? const CircularProgressIndicator(color: Colors.white) 
                      : const Text("SAVE CHANGES", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller, 
    String label, 
    IconData icon, 
    {bool enabled = true, 
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator}
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: _inputDecoration(label, icon),
        validator: validator,
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey),
      prefixIcon: Icon(icon, color: Colors.green),
      filled: true,
      fillColor: const Color(0xFF1C1C1E),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.green)),
    );
  }
}

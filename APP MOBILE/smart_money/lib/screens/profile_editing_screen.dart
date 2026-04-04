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
  final _idCardController = TextEditingController();
  final _addressController = TextEditingController();
  
  String? _selectedGender;
  DateTime? _selectedDate;
  final List<String> _genders = ["Nam", "Nữ", "Khác"];

  @override
  void initState() {
    super.initState();
    // Gọi API lấy dữ liệu mới nhất từ DB khi mở trang
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
        _idCardController.text = user.identityCard ?? "";
        _addressController.text = user.address ?? "";
        
        // Kiểm tra gender hợp lệ trong danh sách
        _selectedGender = _genders.contains(user.gender) ? user.gender : null;
        
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
    _idCardController.dispose();
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
      final request = UpdateProfileRequest(
        fullname: _fullnameController.text,
        identityCard: _idCardController.text,
        address: _addressController.text,
        gender: _selectedGender,
        dateofbirth: _selectedDate != null 
            ? DateFormat('yyyy-MM-dd').format(_selectedDate!) 
            : null,
      );

      final success = await context.read<AuthProvider>().updateProfile(request);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success ? "Cập nhật thành công!" : "Cập nhật thất bại")),
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
        title: const Text("Chỉnh Sửa Hồ Sơ"),
        backgroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTextField(_fullnameController, "Họ và tên", Icons.person),
              _buildTextField(_phoneController, "Số điện thoại", Icons.phone, enabled: false), // Thường không cho sửa phone ở đây
              _buildTextField(_idCardController, "Số CCCD", Icons.badge),
              _buildTextField(_addressController, "Địa chỉ", Icons.location_on),
              
              const SizedBox(height: 16),
              
              // Gender Dropdown
              DropdownButtonFormField<String>(
                value: _selectedGender,
                dropdownColor: const Color(0xFF1C1C1E),
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration("Giới tính", Icons.wc),
                items: _genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                onChanged: (val) => setState(() => _selectedGender = val),
              ),

              const SizedBox(height: 16),

              // Date of Birth Picker
              InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: _inputDecoration("Ngày sinh", Icons.cake),
                  child: Text(
                    _selectedDate == null 
                        ? "Chọn ngày sinh" 
                        : DateFormat('dd/MM/yyyy').format(_selectedDate!),
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
                    // Sử dụng defaultTargetPlatform để an toàn trên Web
                    shape: defaultTargetPlatform == TargetPlatform.android ? const StadiumBorder() : null,
                  ),
                  child: isLoading 
                      ? const CircularProgressIndicator(color: Colors.white) 
                      : const Text("LƯU THAY ĐỔI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        style: const TextStyle(color: Colors.white),
        decoration: _inputDecoration(label, icon),
        validator: (value) => value!.isEmpty ? "Vui lòng nhập $label" : null,
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
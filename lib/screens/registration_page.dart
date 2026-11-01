
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class RegistrationPage extends StatefulWidget {
  final String idToken;
  final Map<String, dynamic> googleUser;

  const RegistrationPage({
    super.key,
    required this.idToken,
    required this.googleUser,
  });

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _companyController = TextEditingController();
  final _designationController = TextEditingController();
  final _locationController = TextEditingController();
  final _addressController = TextEditingController();

  String? _currentStatus;
  bool _loading = false;

  final List<String> _statuses = [
    'Employed',
    'Job Seeker',
    'Student',
    'Other',
  ];

  @override
  void initState() {
    super.initState();

    _nameController.text =
        widget.googleUser['name']?.toString() ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _companyController.dispose();
    _designationController.dispose();
    _locationController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    if (_currentStatus == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('আপনার বর্তমান অবস্থা নির্বাচন করুন।'),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await AuthService.instance.register(
        idToken: widget.idToken,
        fullName: _nameController.text.trim(),
        mobileNumber: _mobileController.text.trim(),
        currentStatus: _currentStatus!,
        companyName: _companyController.text.trim(),
        designation: _designationController.text.trim(),
        jobLocation: _locationController.text.trim(),
        currentAddress: _addressController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration সফল হয়েছে।'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 15,
      ),
    );
  }

  Widget _textField({
    required String label,
    required TextEditingController controller,
    bool requiredField = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: _decoration(label),
        validator: requiredField
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return '$label লিখুন।';
                }
                return null;
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const maroon = Color(0xFF650D18);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registration'),
        backgroundColor: maroon,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Icon(
                Icons.person_add_alt_1,
                size: 55,
                color: maroon,
              ),
              const SizedBox(height: 12),
              const Text(
                'Complete Your Registration',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.googleUser['email']?.toString() ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 25),

              _textField(
                label: 'Full Name',
                controller: _nameController,
                requiredField: true,
              ),

              _textField(
                label: 'Mobile Number',
                controller: _mobileController,
                requiredField: true,
                keyboardType: TextInputType.phone,
              ),

              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: DropdownButtonFormField<String>(
                  value: _currentStatus,
                  decoration: _decoration('Current Status'),
                  items: _statuses.map((status) {
                    return DropdownMenuItem(
                      value: status,
                      child: Text(status),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _currentStatus = value);
                  },
                ),
              ),

              _textField(
                label: 'Company Name (Optional)',
                controller: _companyController,
              ),

              _textField(
                label: 'Designation (Optional)',
                controller: _designationController,
              ),

              _textField(
                label: 'Job Location (Optional)',
                controller: _locationController,
              ),

              _textField(
                label: 'Current Address (Optional)',
                controller: _addressController,
                maxLines: 3,
              ),

              const SizedBox(height: 8),

              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submitRegistration,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: maroon,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                        )
                      : const Text(
                          'Complete Registration',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),
              const Text(
                '* চিহ্নিত তথ্যগুলো বাধ্যতামূলক।',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

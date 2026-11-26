
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

  final _storage = const FlutterSecureStorage();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _companyController = TextEditingController();
  final _designationController = TextEditingController();
  final _locationController = TextEditingController();
  final _addressController = TextEditingController();

  String? _currentStatus;
  bool _loading = false;
  bool _loadingSuggestions = true;

  final List<String> _statuses = [
    'Employed',
    'Job Seeker',
    'Student',
    'Other',
  ];

  String get _suggestionKey {
    final email = (widget.googleUser['email'] ?? 'default')
        .toString()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_');

    return 'registration_suggestions_$email';
  }

  @override
  void initState() {
    super.initState();

    _nameController.text =
        (widget.googleUser['name'] ?? '').toString();

    _emailController.text =
        (widget.googleUser['email'] ?? '').toString();

    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    try {
      final saved = await _storage.read(key: _suggestionKey);

      if (saved != null) {
        final data = jsonDecode(saved);

        if (data is Map<String, dynamic>) {
          _mobileController.text =
              (data['mobile'] ?? '').toString();

          _companyController.text =
              (data['company'] ?? '').toString();

          _designationController.text =
              (data['designation'] ?? '').toString();

          _locationController.text =
              (data['location'] ?? '').toString();

          _addressController.text =
              (data['address'] ?? '').toString();

          final savedStatus = data['status']?.toString();

          if (_statuses.contains(savedStatus)) {
            _currentStatus = savedStatus;
          }
        }
      }
    } catch (_) {
      // Invalid saved suggestions are ignored.
    }

    if (mounted) {
      setState(() => _loadingSuggestions = false);
    }
  }

  Future<void> _saveSuggestions() async {
    final data = {
      'mobile': _mobileController.text.trim(),
      'company': _companyController.text.trim(),
      'designation': _designationController.text.trim(),
      'location': _locationController.text.trim(),
      'address': _addressController.text.trim(),
      'status': _currentStatus,
    };

    try {
      await _storage.write(
        key: _suggestionKey,
        value: jsonEncode(data),
      );
    } catch (_) {
      // Suggestions are optional; do not block registration on damaged local storage.
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
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
        email: _emailController.text.trim(),
        mobileNumber: _mobileController.text.trim(),
        currentStatus: _currentStatus!,
        companyName: _companyController.text.trim(),
        designation: _designationController.text.trim(),
        jobLocation: _locationController.text.trim(),
        currentAddress: _addressController.text.trim(),
      );

      await _saveSuggestions();

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
    Iterable<String>? autofillHints,
    TextCapitalization textCapitalization =
        TextCapitalization.sentences,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        autofillHints: autofillHints,
        textCapitalization: textCapitalization,
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
        child: _loadingSuggestions
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : AutofillGroup(
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
                        _emailController.text,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 25),

                      _textField(
                        label: 'Full Name',
                        controller: _nameController,
                        requiredField: true,
                        autofillHints: const [
                          AutofillHints.name,
                        ],
                      ),

                      _textField(
                        label: 'Email',
                        controller: _emailController,
                        keyboardType:
                            TextInputType.emailAddress,
                        autofillHints: const [
                          AutofillHints.email,
                        ],
                      ),

                      _textField(
                        label: 'Mobile Number',
                        controller: _mobileController,
                        requiredField: true,
                        keyboardType: TextInputType.phone,
                        autofillHints: const [
                          AutofillHints.telephoneNumber,
                        ],
                      ),

                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: 16,
                        ),
                        child:
                            DropdownButtonFormField<String>(
                          initialValue: _currentStatus,
                          decoration:
                              _decoration('Current Status'),
                          items: _statuses.map((status) {
                            return DropdownMenuItem(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _currentStatus = value;
                            });
                          },
                        ),
                      ),

                      _textField(
                        label: 'Company Name (Optional)',
                        controller: _companyController,
                        autofillHints: const [
                          AutofillHints.organizationName,
                        ],
                      ),

                      _textField(
                        label: 'Designation (Optional)',
                        controller: _designationController,
                        autofillHints: const [
                          AutofillHints.jobTitle,
                        ],
                      ),

                      _textField(
                        label: 'Job Location (Optional)',
                        controller: _locationController,
                        autofillHints: const [
                          AutofillHints.addressCity,
                        ],
                      ),

                      _textField(
                        label: 'Current Address (Optional)',
                        controller: _addressController,
                        autofillHints: const [
                          AutofillHints.fullStreetAddress,
                        ],
                        maxLines: 3,
                      ),

                      const SizedBox(height: 8),

                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _loading
                              ? null
                              : _submitRegistration,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: maroon,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
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
                        '* Name, Mobile Number ও Current Status বাধ্যতামূলক।',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

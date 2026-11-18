import 'package:flutter/material.dart';

import '../services/auth_service.dart';

/// Only editable profile fields are sent to the server. Google email and
/// Google identity are intentionally read-only.
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _mobile;
  late final TextEditingController _company;
  late final TextEditingController _designation;
  late final TextEditingController _location;
  late final TextEditingController _address;

  static const statuses = ['Employed', 'Job Seeker', 'Student', 'Other'];
  late String _status;
  bool _saving = false;

  String _initial(String key) => widget.user[key]?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: _initial('full_name'));
    _mobile = TextEditingController(text: _initial('mobile_number'));
    _company = TextEditingController(text: _initial('company_name'));
    _designation = TextEditingController(text: _initial('designation'));
    _location = TextEditingController(text: _initial('job_location'));
    _address = TextEditingController(text: _initial('current_address'));
    final initialStatus = _initial('current_status');
    _status = statuses.contains(initialStatus) ? initialStatus : statuses.first;
  }

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _company.dispose();
    _designation.dispose();
    _location.dispose();
    _address.dispose();
    super.dispose();
  }

  String tr(String bn, String en) =>
      Localizations.localeOf(context).languageCode == 'bn' ? bn : en;

  Widget field(
    TextEditingController controller,
    String label, {
    int maxLength = 150,
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: controller,
          maxLength: maxLength,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(labelText: label),
          validator: (value) {
            final text = value?.trim() ?? '';
            if (required && text.isEmpty) {
              return tr('এই তথ্যটি প্রয়োজন।', 'This field is required.');
            }
            if (controller == _mobile &&
                !RegExp(r'^[0-9+\-\s()]{7,20}$').hasMatch(text)) {
              return tr('সঠিক মোবাইল নম্বর লিখুন।', 'Enter a valid phone number.');
            }
            return null;
          },
        ),
      );

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await AuthService.instance.updateProfile(
        fullName: _name.text.trim(),
        mobileNumber: _mobile.text.trim(),
        currentStatus: _status,
        companyName: _company.text.trim(),
        designation: _designation.text.trim(),
        jobLocation: _location.text.trim(),
        currentAddress: _address.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error.toString().replaceFirst('Exception: ', '')),
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(tr('প্রোফাইল এডিট', 'Edit profile'))),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                Text(
                  tr('নাম, ফোন ও পেশাগত তথ্য পরিবর্তন করুন।',
                      'Update your name, phone and professional details.'),
                ),
                const SizedBox(height: 18),
                field(_name, tr('পূর্ণ নাম', 'Full name'),
                    required: true, maxLength: 150),
                TextFormField(
                  initialValue: _initial('email'),
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: tr('ইমেইল (Google অ্যাকাউন্ট)',
                        'Email (Google account)'),
                    helperText: tr('ইমেইল পরিবর্তন করা যাবে না।',
                        'Email cannot be changed here.'),
                  ),
                ),
                const SizedBox(height: 14),
                field(_mobile, tr('মোবাইল নম্বর', 'Mobile number'),
                    required: true,
                    maxLength: 20,
                    keyboardType: TextInputType.phone),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String>(
                    value: _status,
                    decoration: InputDecoration(
                        labelText: tr('বর্তমান অবস্থা', 'Employment status')),
                    items: statuses
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _status = value ?? _status),
                  ),
                ),
                field(_company, tr('কোম্পানি', 'Company'), maxLength: 200),
                field(_designation, tr('পদবি', 'Designation'), maxLength: 150),
                field(_location, tr('কর্মস্থল', 'Workplace'), maxLength: 200),
                field(_address, tr('বর্তমান ঠিকানা', 'Current address'),
                    maxLength: 2000, maxLines: 3),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving
                      ? tr('সংরক্ষণ হচ্ছে...', 'Saving...')
                      : tr('পরিবর্তন সংরক্ষণ করুন', 'Save changes')),
                ),
                ],
              ),
            ),
          ),
        ),
      );
}

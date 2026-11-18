import 'package:flutter/material.dart';
import '../services/job_submission_service.dart';

const _maroon = Color(0xFF650D18);

class SubmitJobPage extends StatefulWidget {
  const SubmitJobPage({super.key});
  @override
  State<SubmitJobPage> createState() => _SubmitJobPageState();
}

class _SubmitJobPageState extends State<SubmitJobPage> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _organization = TextEditingController();
  final _mobile = TextEditingController();
  final _whatsapp = TextEditingController();
  final _location = TextEditingController();
  final _employment = TextEditingController();
  final _salary = TextEditingController();
  final _vacancies = TextEditingController();
  final _description = TextEditingController();
  final _requirements = TextEditingController();
  final _url = TextEditingController();
  DateTime? _deadline;
  bool _sameWhatsApp = true;
  bool _publicContact = false;
  bool _saving = false;
  late Future<List<Map<String, dynamic>>> _mySubmissions;

  @override
  void initState() {
    super.initState();
    _refreshMySubmissions();
  }

  void _refreshMySubmissions() {
    _mySubmissions = JobSubmissionService.instance.mySubmissions();
  }

  @override
  void dispose() {
    for (final c in [
      _title, _organization, _mobile, _whatsapp, _location, _employment,
      _salary, _vacancies, _description, _requirements, _url,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? value) =>
      (value ?? '').trim().isEmpty ? 'এই তথ্যটি লিখুন' : null;

  String? _phone(String? value) {
    if (!RegExp(r'^\+?[0-9]{8,15}$').hasMatch((value ?? '').trim())) {
      return '৮–১৫ সংখ্যার সঠিক মোবাইল নম্বর দিন';
    }
    return null;
  }

  String? _https(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return 'সঠিক HTTPS লিংক দিন';
    }
    return null;
  }

  Future<void> _chooseDeadline() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (selected != null && mounted) setState(() => _deadline = selected);
  }

  String? get _deadlineValue {
    final date = _deadline;
    if (date == null) return null;
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return date.year.toString() + '-' + m + '-' + d;
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      await JobSubmissionService.instance.submit({
        'title': _title.text.trim(),
        'organization': _organization.text.trim(),
        'mobile_number': _mobile.text.trim(),
        'whatsapp_number': _sameWhatsApp
            ? _mobile.text.trim()
            : _whatsapp.text.trim(),
        'public_contact': _publicContact,
        'location': _location.text.trim(),
        'employment_type': _employment.text.trim(),
        'salary': _salary.text.trim(),
        'vacancies': _vacancies.text.trim(),
        'description': _description.text.trim(),
        'requirements': _requirements.text.trim(),
        'application_url': _url.text.trim(),
        'application_deadline': _deadlineValue ?? '',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('সার্কুলার জমা হয়েছে। Admin অনুমোদনের অপেক্ষায় আছে।'),
        ),
      );
      _form.currentState!.reset();
      for (final c in [
        _title, _organization, _mobile, _whatsapp, _location, _employment,
        _salary, _vacancies, _description, _requirements, _url,
      ]) {
        c.clear();
      }
      setState(() {
        _deadline = null;
        _sameWhatsApp = true;
        _publicContact = false;
        _refreshMySubmissions();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    bool required = false,
    int maxLines = 1,
    int maxLength = 200,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        keyboardType: keyboardType,
        validator: validator ?? (required ? _required : null),
        decoration: InputDecoration(
          labelText: required ? label + ' *' : label,
          hintText: hint,
          border: const OutlineInputBorder(),
          alignLabelWithHint: maxLines > 1,
        ),
      ),
    );
  }

  Widget _myPosts() => FutureBuilder<List<Map<String, dynamic>>>(
        future: _mySubmissions,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return TextButton.icon(
              onPressed: () => setState(_refreshMySubmissions),
              icon: const Icon(Icons.refresh),
              label: const Text('আমার সার্কুলার লোড হয়নি — আবার চেষ্টা'),
            );
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Text('আপনি এখনো কোনো সার্কুলার জমা দেননি।');
          }
          return Column(
            children: [
              for (final item in items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item['title']?.toString() ?? ''),
                  subtitle: Text(
                    (item['organization']?.toString() ?? '') +
                    (item['admin_note'] == null
                        ? ''
                        : '\nAdmin: ' + item['admin_note'].toString()),
                  ),
                  isThreeLine: item['admin_note'] != null,
                  trailing: Text(
                    switch (item['status']) {
                      'approved' => 'Approved',
                      'rejected' => 'Rejected',
                      _ => 'Pending',
                    },
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: item['status'] == 'approved'
                          ? Colors.green
                          : item['status'] == 'rejected'
                              ? Colors.red
                              : Colors.orange.shade800,
                    ),
                  ),
                ),
            ],
          );
        },
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('চাকরির সার্কুলার জমা দিন'),
          backgroundColor: const Color(0xFF36060D),
          foregroundColor: Colors.white,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: Theme.of(context).colorScheme.surface,
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'আপনার দেওয়া সার্কুলার প্রথমে Admin যাচাই করবেন। '
                  'অনুমোদন না হওয়া পর্যন্ত অন্য কেউ এটি দেখতে পাবেন না। '
                  'ভুয়া বা বিভ্রান্তিকর বিজ্ঞপ্তি জমা দেবেন না।',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Form(
              key: _form,
              child: Column(
                children: [
                  _field('পদের নাম', _title, required: true, maxLength: 255),
                  _field('প্রতিষ্ঠানের নাম', _organization,
                      required: true, maxLength: 200),
                  _field('যোগাযোগের মোবাইল', _mobile,
                      required: true, maxLength: 20,
                      keyboardType: TextInputType.phone, validator: _phone),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _sameWhatsApp,
                    onChanged: (v) => setState(() => _sameWhatsApp = v ?? true),
                    title: const Text('WhatsApp নম্বর একই'),
                  ),
                  if (!_sameWhatsApp)
                    _field('WhatsApp নম্বর', _whatsapp,
                        required: true, maxLength: 20,
                        keyboardType: TextInputType.phone, validator: _phone),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _publicContact,
                    onChanged: (v) => setState(() => _publicContact = v ?? false),
                    title: const Text(
                      'অনুমোদনের পর আমার মোবাইল ও WhatsApp নম্বর সবাই দেখতে পারবেন',
                    ),
                    subtitle: const Text(
                      'সম্মতি না দিলে নম্বর শুধু Admin দেখতে পারবেন।',
                    ),
                  ),
                  _field('কর্মস্থল', _location),
                  _field('চাকরির ধরন', _employment, maxLength: 100,
                      hint: 'Full Time / Part Time'),
                  _field('বেতন', _salary, maxLength: 120),
                  _field('পদসংখ্যা', _vacancies, maxLength: 80),
                  _field('চাকরির বিবরণ', _description,
                      required: true, maxLines: 7, maxLength: 60000),
                  _field('যোগ্যতা ও অভিজ্ঞতা', _requirements,
                      maxLines: 5, maxLength: 60000),
                  _field('আবেদনের লিংক (HTTPS)', _url,
                      maxLength: 2048, keyboardType: TextInputType.url,
                      validator: _https),
                  OutlinedButton.icon(
                    onPressed: _chooseDeadline,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(_deadlineValue == null
                        ? 'আবেদনের শেষ তারিখ (ঐচ্ছিক)'
                        : 'শেষ তারিখ: ' + _deadlineValue!),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _saving ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: _maroon,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    icon: _saving
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined),
                    label: Text(_saving ? 'জমা হচ্ছে...' : 'Admin Approval-এর জন্য জমা দিন'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                const Expanded(
                  child: Text('আমার জমা দেওয়া সার্কুলার',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  onPressed: () => setState(_refreshMySubmissions),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            _myPosts(),
          ],
        ),
      );
}

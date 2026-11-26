import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/design_system.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_guard.dart';
import '../settings/app_settings.dart';
import '../services/auth_service.dart';
import '../services/career_service.dart';

class CareerPage extends StatelessWidget {
  const CareerPage({super.key});
  static Future<void> open(BuildContext context, {String? section}) async {
    if (!await AuthGuard.ensureAuthenticated(context) || !context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => section == null ? const CareerPage() : CareerSection(section: section),
    ));
  }
  @override
  Widget build(BuildContext context) {
    String tr(String bn, String en) => AppText.of(context, bn, en);
    final entries = [
      ('alerts', Icons.notifications_active_outlined, tr('চাকরির এলার্ট','Job alerts'), tr('পদ ও কর্মস্থল অনুযায়ী চাকরি','Jobs matching your preferences')),
      ('mock', Icons.record_voice_over_outlined, tr('মক ইন্টারভিউ','Mock interview'), tr('উত্তর অনুশীলন ও মূল্যায়ন','Practice and self-assess answers')),
      ('courses', Icons.school_outlined, tr('প্রশিক্ষণ ও কোর্স','Training & courses'), tr('প্রকাশিত প্রশিক্ষণের তথ্য','Explore published courses')),
      ('directory', Icons.groups_outlined, tr('পেশাজীবী ডিরেক্টরি','Professional directory'), tr('ঐচ্ছিক পেশাগত পরিচিতি','Optional professional profiles')),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(tr('ক্যারিয়ার ডেভেলপমেন্ট','Career development'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        FsFeatureCard(icon: Icons.trending_up_rounded, title: tr('ক্যারিয়ার গ্রোথ','Career growth'),
          subtitle: tr('চাকরি • দক্ষতা • প্রশিক্ষণ • পরিচিতি','Jobs • Skills • Training • Network')),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, constraints) {
          final largeText = MediaQuery.textScalerOf(context).scale(14) > 19;
          final columns = constraints.maxWidth < 340 || largeText ? 1 : constraints.maxWidth >= 720 ? 4 : 2;
          final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            for (final e in entries) SizedBox(width: width, child: FsFeatureCard(
              vertical: true, icon: e.$2, title: e.$3, subtitle: e.$4,
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => CareerSection(section: e.$1))),
            )),
          ]);
        }),
      ]),
    );
  }
}

class CareerSection extends StatefulWidget {
  const CareerSection({super.key, required this.section});
  final String section;
  @override
  State<CareerSection> createState() => _CareerSectionState();
}

class _CareerSectionState extends State<CareerSection> {
  final _directorySearch = TextEditingController();
  final _keyword = TextEditingController(), _location = TextEditingController(),
      _name = TextEditingController(), _role = TextEditingController(),
      _organization = TextEditingController(), _city = TextEditingController();
  List<Map<String, dynamic>> _rows = [];
  bool _busy = true, _enabled = false, _consent = false, _revealed = false, _editingProfile = false;
  Uint8List? _selectedPhoto;
  String _photoPath = '';
  String _directoryQuery = '';
  bool _removePhoto = false;
  String? _error, _next;
  String _status = '';
  int _index = 0, _score = 0;
  String get _section => widget.section;
  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() {
    for (final c in [_directorySearch,_keyword,_location,_name,_role,_organization,_city]) { c.dispose(); }
    super.dispose();
  }
  Future<void> _load({bool more = false}) async {
    setState(() { _busy = true; _error = null; if (!more) { _rows = []; _next = null; } });
    try {
      final token = await AuthService.instance.getSessionToken();
      final data = await CareerService.request(_section, filters: {
        if (more && _next != null) 'before_id': _next!,
        if (_section == 'mock') 'role': _role.text.trim(),
        if (_section == 'directory' && _directoryQuery.isNotEmpty) 'q': _directoryQuery,
      });
      Map<String, dynamic>? profile;
      if (_section == 'directory' && !more) {
        final mine = await CareerService.request('my_profile');
        if (mine['profile'] is Map) profile = Map<String, dynamic>.from(mine['profile'] as Map);
      }
      if (await AuthService.instance.getSessionToken() != token) throw const FormatException('Session changed');
      if (!mounted) return;
      setState(() {
        _rows = [..._rows, ...CareerService.rows(data)];
        _next = data['next_before_id']?.toString();
        if (_section == 'alerts') {
          final p = Map<String, dynamic>.from(data['preferences'] as Map);
          _enabled = p['enabled'] == true; _keyword.text = CareerService.text(p,'keyword'); _location.text = CareerService.text(p,'location');
        }
        if (_section == 'directory' && !more) {
          final p = profile ?? <String,dynamic>{};
          _name.text = CareerService.text(p,'display_name'); _role.text = CareerService.text(p,'role_name');
          _organization.text = CareerService.text(p,'organization'); _city.text = CareerService.text(p,'city');
          _status = CareerService.text(p,'status'); _photoPath = CareerService.text(p,'photo_path'); _consent = false; _selectedPhoto = null; _removePhoto = false;
        }
        if (_section == 'mock') { _index = 0; _score = 0; _revealed = false; }
      });
    } catch (e) { if (mounted) setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  void _searchDirectory() {
    if (_busy || _editingProfile) return;
    _directoryQuery = _directorySearch.text.trim();
    _load();
  }
  Future<void> _pickProfilePhoto() async {
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 82, maxWidth: 720, maxHeight: 720);
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (bytes.length > 2097152) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ছবির আকার ২ MB-এর মধ্যে রাখুন')));
        return;
      }
      if (mounted) setState(() { _selectedPhoto = bytes; _removePhoto = false; });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ছবি নির্বাচন করা যায়নি')));
    }
  }
  Future<void> _write(String action, Map<String,dynamic> body) async {
    setState(() { _busy = true; _error = null; });
    try {
      final data = await CareerService.request(action, body: body);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(action == 'check_alerts'
          ? 'নতুন নোটিফিকেশন: ${data['new_alerts']}' : 'সংরক্ষণ হয়েছে')));
      if (action == 'save_profile' || action == 'hide_profile') setState(() => _editingProfile = false);
      await _load();
    } catch (e) { if (mounted) setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Widget _field(TextEditingController controller, String label, int max) => Padding(
    padding: const EdgeInsets.only(bottom: 8), child: TextField(controller: controller,
      enabled: !_busy, maxLength: max, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), counterText: '')));
  Widget _link(String raw) {
    final uri = CareerService.safeLink(raw);
    if (uri == null) return const SizedBox.shrink();
    return TextButton.icon(icon: const Icon(Icons.open_in_new), label: const Text('বিস্তারিত লিংক'),
      onPressed: () async {
        try { if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return; } catch (_) {}
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('লিংক খোলা যায়নি')));
      });
  }
  Widget _card(String title, String detail, {String link = ''}) => Card(child: Padding(
    padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6), Text(detail), _link(link),
    ])));
  void _rate(bool correct) => setState(() { if (correct) _score++; _index++; _revealed = false; });
  List<Widget> _content() {
    if (_section == 'alerts') return [
      const Text('গত ৩০ দিনের প্রকাশিত ও মেয়াদ না পেরোনো বিজ্ঞপ্তি থেকে শব্দের মিল। যোগ্যতা নিশ্চিত করে না। নতুন মিল থাকা চাকরি চেক করলে অ্যাপের ইনবক্সে নোটিফিকেশন যোগ হবে; মোবাইল পুশ নয়।'),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Job Alert চালু'), value: _enabled, onChanged: _busy ? null : (v) => setState(() => _enabled = v)),
      _field(_keyword,'পদ / যোগ্যতার শব্দ',120), _field(_location,'কর্মস্থল',120),
      FilledButton(onPressed: _busy ? null : () => _write('save_alerts',{'enabled':_enabled,'keyword':_keyword.text.trim(),'location':_location.text.trim()}), child: const Text('পছন্দ সংরক্ষণ')),
      OutlinedButton(onPressed: _busy ? null : () => _write('check_alerts',{}), child: const Text('নতুন চাকরি চেক করুন')),
      const SizedBox(height: 12), const Text('মিল থাকা চাকরি', style: TextStyle(fontWeight: FontWeight.bold)),
      for(final row in _rows) _card(CareerService.text(row,'title'),
        ['organization','location','requirements','application_deadline'].map((k)=>CareerService.text(row,k)).where((v)=>v.isNotEmpty).join('\n'),link:CareerService.text(row,'apply_url')),
    ];
    if (_section == 'mock') return [
      const Text('প্রথমে নিজে উত্তর বলুন। নমুনা উত্তরের সঙ্গে মিলিয়ে নিজেকে মূল্যায়ন করুন। এটি AI বা পরীক্ষকের মূল্যায়ন নয়।'),
      const SizedBox(height: 10), _field(_role,'পদের নাম (ঐচ্ছিক, সঠিক নাম)',120),
      FilledButton(onPressed: _busy ? null : () => _load(), child: const Text('নতুন অনুশীলন শুরু')),
      if (_rows.isNotEmpty && _index < _rows.length) ...[
        const SizedBox(height: 12),
        LinearProgressIndicator(value: _index / _rows.length),
        _card('প্রশ্ন ${_index + 1}/${_rows.length}',CareerService.text(_rows[_index],'title')),
        if (!_revealed) FilledButton(onPressed: _busy ? null : () => setState(() => _revealed = true), child: const Text('নমুনা উত্তর দেখুন'))
        else ...[
          _card('নমুনা উত্তর',CareerService.text(_rows[_index],'body')),
          FilledButton(onPressed: _busy ? null : () => _rate(true), child: const Text('উত্তর মিলেছে')),
          OutlinedButton(onPressed: _busy ? null : () => _rate(false), child: const Text('আরও অনুশীলন দরকার')),
        ]
      ] else if (_rows.isNotEmpty) _card('অনুশীলন সম্পন্ন','নিজস্ব মূল্যায়ন: $_score / ${_rows.length}'),
    ];
    if (_section == 'courses') return [
      const Text('প্রতিষ্ঠান, তারিখ, ফি ও সনদের তথ্য অফিসিয়াল উৎসে যাচাই করুন। অ্যাপের মাধ্যমে কোর্সে ভর্তি বা পেমেন্ট হয় না।'),
      for(final row in _rows) _card(CareerService.text(row,'title'),
        ['provider','location','start_date','description'].map((k)=>CareerService.text(row,k)).where((v)=>v.isNotEmpty).join('\n'),link:CareerService.text(row,'course_url')),
    ];
    final query = _directoryQuery;
    final visibleProfiles = _rows;
    return [
      Card(child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('পেশাজীবী খুঁজুন বা নিজের প্রোফাইল যোগ করুন।'),
          const SizedBox(height: 12),
          TextField(
            controller: _directorySearch,
            enabled: !_busy && !_editingProfile,
            maxLength: 160,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _searchDirectory(),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'নাম, পদবি বা প্রতিষ্ঠান খুঁজুন',
              border: const OutlineInputBorder(),
              counterText: '',
              suffixIcon: IconButton(onPressed: _busy || _editingProfile ? null : _searchDirectory, icon: const Icon(Icons.search), tooltip: 'খুঁজুন'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: FilledButton.icon(
            onPressed: _busy ? null : () => setState(() => _editingProfile = !_editingProfile),
            icon: Icon(_editingProfile ? Icons.close : Icons.person_add_alt_1),
            label: Text(_editingProfile ? 'বন্ধ করুন' : 'প্রোফাইল যোগ করুন'),
          )),
        ]),
      )),
      if (_status.isNotEmpty) Card(child: ListTile(
        leading: Icon(_status == 'approved' ? Icons.verified_outlined : Icons.hourglass_top,
          color: _status == 'approved' ? Colors.green : null),
        title: const Text('আপনার প্রোফাইলের অবস্থা'),
        subtitle: Text(({'pending':'অনুমোদনের অপেক্ষায়','approved':'প্রকাশিত','hidden':'লুকানো'})[_status] ?? _status),
      )),
      if (_editingProfile) ...[
        const SizedBox(height: 8),
        Center(child: Column(children: [
          if (_selectedPhoto != null)
            CircleAvatar(radius: 46, backgroundImage: MemoryImage(_selectedPhoto!))
          else
            _PrivateProfileAvatar(photoKey: _removePhoto ? '' : _photoPath, radius: 46),
          if (_selectedPhoto != null || (!_removePhoto && _photoPath.isNotEmpty))
            TextButton.icon(onPressed: _busy ? null : () => setState(() {
              _selectedPhoto = null;
              _removePhoto = true;
            }), icon: const Icon(Icons.delete_outline), label: const Text('ছবি সরান')),
          TextButton.icon(onPressed:_busy?null:_pickProfilePhoto,icon:const Icon(Icons.add_a_photo_outlined),label:const Text('ছবি নির্বাচন করুন')),
          const Text('ছবি স্বয়ংক্রিয়ভাবে ছোট হবে',style:TextStyle(fontSize:12)), 
        ])),
        Text('প্রোফাইল তথ্য', style: Theme.of(context).textTheme.titleMedium),
        const Text('অনুমোদনের পর নিবন্ধিত ব্যবহারকারীরা দেখবেন। ফোন বা ইমেইল দেবেন না। এটি সনদ যাচাই নয়।'),
        const SizedBox(height: 12),
        _field(_name,'প্রদর্শিত নাম',100),
        _field(_role,'পদ / পেশা',120),
        _field(_organization,'প্রতিষ্ঠান (ঐচ্ছিক)',120),
        _field(_city,'শহর (ঐচ্ছিক)',100),
        CheckboxListTile(contentPadding: EdgeInsets.zero,value:_consent,onChanged:_busy?null:(v)=>setState(()=>_consent=v==true),
          title:const Text('আমার তথ্য নিবন্ধিত ব্যবহারকারীদের দেখাতে সম্মত।')),
        SizedBox(width: double.infinity, child: FilledButton.icon(
          onPressed:_busy||!_consent?null:()=>_write('save_profile',{'consent':true,'display_name':_name.text,'role_name':_role.text,'organization':_organization.text,'city':_city.text,if(_selectedPhoto!=null)'photo_base64':base64Encode(_selectedPhoto!),if(_removePhoto)'remove_photo':true}),
          icon: const Icon(Icons.send_outlined), label:const Text('জমা দিন'))),
        if(_status.isNotEmpty&&_status!='hidden') OutlinedButton(
          onPressed:_busy?null:()=>_write('hide_profile',{}),child:const Text('আমার পরিচিতি লুকান')),
      ],
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: Text('পেশাজীবী', 
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
        Text('${visibleProfiles.length} জন', style: Theme.of(context).textTheme.bodySmall),
      ]),
      const SizedBox(height: 8),
      if (visibleProfiles.isEmpty) Card(
        child: Padding(padding: const EdgeInsets.all(20), child: Center(
          child: Text(query.isEmpty ? 'এখনো কোনো প্রোফাইল নেই।' : 'কোনো প্রোফাইল পাওয়া যায়নি।'),
        )),
      ),
      for (final row in visibleProfiles) Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _PrivateProfileAvatar(key: ValueKey(CareerService.text(row,'id')), photoKey: CareerService.text(row,'photo_path'), radius: 30),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(CareerService.text(row,'display_name'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(CareerService.text(row,'role_name'),
                style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
              if (CareerService.text(row,'organization').isNotEmpty) ...[
                const SizedBox(height: 5),
                Row(children: [const Icon(Icons.business_outlined,size:16),const SizedBox(width:5),
                  Expanded(child: Text(CareerService.text(row,'organization')))]),
              ],
              if (CareerService.text(row,'city').isNotEmpty) ...[
                const SizedBox(height: 3),
                Row(children: [const Icon(Icons.location_on_outlined,size:16),const SizedBox(width:5),
                  Expanded(child: Text(CareerService.text(row,'city')))]),
              ],
              const SizedBox(height: 5),
              const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_circle_outline, size: 14, color: Colors.green),
                SizedBox(width: 4),
                Text('অ্যাডমিন অনুমোদিত পরিচিতি', style: TextStyle(fontSize: 11)),
              ]),
            ])),
          ]),
        ),
      ),
    ];
  }
  @override
  Widget build(BuildContext context) {
    String tr(String bn, String en) => AppText.of(context, bn, en);
    final titles = {
      'alerts': tr('চাকরির বিজ্ঞপ্তি', 'Job Alerts'),
      'mock': tr('মক ইন্টারভিউ', 'Mock Interview'),
      'courses': tr('প্রশিক্ষণ ও কোর্স', 'Training & Courses'),
      'directory': tr('পেশাজীবী ডিরেক্টরি', 'Professional Directory'),
    };
    return Scaffold(
    appBar: AppBar(
      title: Row(
        children: [
          if (_section == 'directory') ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.groups_outlined,
                color: Theme.of(context).colorScheme.primary, size: 23),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              titles[_section] ?? tr('ক্যারিয়ার', 'Career'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: _busy ? null : () => _load(),
          icon: const Icon(Icons.refresh),
          tooltip: tr('রিফ্রেশ', 'Refresh'),
        ),
      ],
    ),
    body: ListView(padding:const EdgeInsets.all(16),children:[
      if(_busy) const LinearProgressIndicator(),
      if(_error != null) Padding(padding:const EdgeInsets.symmetric(vertical:12),child:Text(_error!,style:TextStyle(color:Theme.of(context).colorScheme.error))),
      if(!_busy || _rows.isNotEmpty) ..._content(),
      if(_section!='directory'&&!_busy&&_error==null&&_rows.isEmpty) const Padding(padding:EdgeInsets.all(12),child:Text('এখন কোনো তথ্য পাওয়া যায়নি।')),
      if(_next!=null) OutlinedButton(onPressed:_busy?null:()=>_load(more:true),child:const Text('আরও দেখুন')),
    ]));
  }
}


class _PrivateProfileAvatar extends StatefulWidget {
  const _PrivateProfileAvatar({super.key, required this.photoKey, required this.radius});
  final String photoKey;
  final double radius;
  @override
  State<_PrivateProfileAvatar> createState() => _PrivateProfileAvatarState();
}

class _PrivateProfileAvatarState extends State<_PrivateProfileAvatar> {
  late Future<Uint8List?> _photo;
  @override
  void initState() {
    super.initState();
    _photo = CareerService.photoBytes(widget.photoKey);
  }
  @override
  void didUpdateWidget(covariant _PrivateProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoKey != widget.photoKey) {
      _photo = CareerService.photoBytes(widget.photoKey);
    }
  }
  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    future: _photo,
    builder: (context, snapshot) {
      final bytes = snapshot.connectionState == ConnectionState.done ? snapshot.data : null;
      return CircleAvatar(
        radius: widget.radius,
        child: bytes == null
          ? Icon(Icons.person_outline, size: widget.radius)
          : ClipOval(child: Image.memory(bytes, width: widget.radius * 2, height: widget.radius * 2,
            fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.person_outline, size: widget.radius))),
      );
    },
  );
}

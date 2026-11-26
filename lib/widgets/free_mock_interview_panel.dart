import 'dart:async';

import 'package:flutter/material.dart';
import '../services/mock_interview_evaluator.dart';
import '../services/offline_voice_service.dart';

/// Free, local-only text and voice practice for the existing question bank.
/// Voice features never fall back to an online recognizer or network TTS.
class FreeMockInterviewPanel extends StatefulWidget {
  const FreeMockInterviewPanel({
    super.key,
    required this.questions,
    required this.role,
    this.onRestart,
  });

  final List<Map<String, dynamic>> questions;
  final String role;
  final VoidCallback? onRestart;

  @override
  State<FreeMockInterviewPanel> createState() => _FreeMockInterviewPanelState();
}

class _FreeMockInterviewPanelState extends State<FreeMockInterviewPanel> {
  final TextEditingController _answer = TextEditingController();
  StreamSubscription<Map<String, dynamic>>? _voiceSubscription;
  int _index = 0;
  final List<int> _completedScores = [];
  MockInterviewEvaluation? _evaluation;
  bool _showSample = false;
  bool _listening = false;
  bool _speaking = false;
  bool _localeInitialized = false;
  String _localeTag = 'bn-BD';
  String _voiceMessage = 'ভয়েস সুবিধা ব্যবহার করতে মাইক্রোফোন চাপুন।';

  Map<String, dynamic>? get _question =>
      _index < widget.questions.length ? widget.questions[_index] : null;

  String _text(Map<String, dynamic>? row, String key) =>
      row?[key]?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _voiceSubscription = OfflineVoiceService.events.listen(
      _handleVoiceEvent,
      onError: (_) {
        if (mounted) {
          setState(() {
            _listening = false;
            _voiceMessage = 'ভয়েস সুবিধা পাওয়া যায়নি। লিখে উত্তর দিতে পারেন।';
          });
        }
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_localeInitialized) {
      _localeTag = Localizations.localeOf(context).languageCode == 'en'
          ? 'en-US'
          : 'bn-BD';
      _localeInitialized = true;
    }
  }

  @override
  void didUpdateWidget(covariant FreeMockInterviewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.questions, widget.questions)) {
      _stopVoiceFeatures();
      _index = 0;
      _completedScores.clear();
      _evaluation = null;
      _showSample = false;
      _answer.clear();
    }
  }

  @override
  void dispose() {
    _voiceSubscription?.cancel();
    _stopVoiceFeatures();
    _answer.dispose();
    super.dispose();
  }

  void _handleVoiceEvent(Map<String, dynamic> event) {
    if (!mounted) return;
    final type = event['type']?.toString() ?? '';
    if (type == 'partial' || type == 'result') {
      final transcript = event['text']?.toString() ?? '';
      if (transcript.isNotEmpty) {
        _answer.value = TextEditingValue(
          text: transcript,
          selection: TextSelection.collapsed(offset: transcript.length),
        );
      }
      if (type == 'result') {
        setState(() {
          _listening = false;
          _voiceMessage = 'ভয়েস থেকে লেখা তৈরি হয়েছে। প্রয়োজন হলে সম্পাদনা করুন।';
        });
      }
    } else if (type == 'listening') {
      setState(() {
        _listening = true;
        _voiceMessage = 'শুনছি… উত্তর বলা শেষ হলে Stop চাপুন।';
      });
    } else if (type == 'speech_done') {
      setState(() => _speaking = false);
    } else if (type == 'speech_error') {
      setState(() {
        _speaking = false;
        _voiceMessage = 'প্রশ্ন পড়ে শোনানো যায়নি।';
      });
    } else if (type == 'error') {
      setState(() {
        _listening = false;
        _voiceMessage = _speechError(event['code']?.toString() ?? '');
      });
    }
  }

  String _speechError(String code) {
    switch (code) {
      case '7':
        return 'কথা বোঝা যায়নি। আবার চেষ্টা করুন অথবা লিখে উত্তর দিন।';
      case '8':
        return 'ভয়েস সেবা এখন ব্যস্ত। পরে আবার চেষ্টা করুন।';
      case '9':
        return 'মাইক্রোফোন অনুমতি প্রয়োজন।';
      case '10':
        return 'ভয়েস ইনপুট বাতিল হয়েছে।';
      case '11':
        return 'অফলাইন ভয়েস সেবা সংযোগ করা যায়নি।';
      case '12':
        return 'এই ভাষার অফলাইন ভয়েস মডেল ইনস্টল নেই।';
      case '13':
        return 'এই ভাষা অফলাইনে সমর্থিত নয়।';
      default:
        return 'অফলাইন ভয়েস কাজ করেনি। লিখে উত্তর দিতে পারেন।';
    }
  }

  Future<void> _startListening() async {
    try {
      final granted =
          await OfflineVoiceService.requestMicrophonePermission();
      if (!granted) {
        setState(() => _voiceMessage =
            'মাইক্রোফোন অনুমতি ছাড়া ভয়েস ব্যবহার করা যাবে না।');
        return;
      }
      final available =
          await OfflineVoiceService.isOfflineSpeechAvailable();
      if (!available) {
        setState(() => _voiceMessage =
            'এই ফোনে Android 12+ অন-ডিভাইস Speech Recognition নেই। Text Interview ব্যবহার করুন।');
        return;
      }
      await OfflineVoiceService.startListening(_localeTag);
      if (mounted) {
        setState(() {
          _listening = true;
          _voiceMessage = 'শুনছি… উত্তর বলা শেষ হলে Stop চাপুন।';
        });
      }
    } on Exception catch (error) {
      if (mounted) {
        setState(() {
          _listening = false;
          _voiceMessage = error.toString().contains('OFFLINE_SPEECH')
              ? 'এই ফোনে অফলাইন ভয়েস মডেল পাওয়া যায়নি।'
              : 'মাইক্রোফোন চালু করা যায়নি। লিখে উত্তর দিতে পারেন।';
        });
      }
    }
  }

  Future<void> _stopListening() async {
    try {
      await OfflineVoiceService.stopListening();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _listening = false;
        _voiceMessage = 'ভয়েস ইনপুট বন্ধ হয়েছে। লেখা সম্পাদনা করতে পারেন।';
      });
    }
  }

  Future<void> _speakQuestion() async {
    final question = _text(_question, 'title').trim();
    if (question.isEmpty) return;
    try {
      await OfflineVoiceService.stopSpeaking();
      await OfflineVoiceService.speak(question, _localeTag);
      if (mounted) {
        setState(() {
          _speaking = true;
          _voiceMessage = 'ফোনের অফলাইন ভয়েসে প্রশ্ন পড়া হচ্ছে।';
        });
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _speaking = false;
          _voiceMessage =
              'এই ভাষার অফলাইন Text-to-Speech ভয়েস ফোনে ইনস্টল নেই।';
        });
      }
    }
  }

  Future<void> _stopSpeaking() async {
    try {
      await OfflineVoiceService.stopSpeaking();
    } catch (_) {}
    if (mounted) setState(() => _speaking = false);
  }

  Future<void> _stopVoiceFeatures() async {
    try {
      await OfflineVoiceService.cancelListening();
      await OfflineVoiceService.stopSpeaking();
    } catch (_) {}
  }

  void _evaluateAnswer() {
    final result = MockInterviewEvaluation.evaluate(
      answer: _answer.text,
      sampleAnswer: _text(_question, 'body'),
    );
    setState(() {
      _evaluation = result;
      _showSample = false;
    });
  }

  void _nextQuestion() {
    final result = _evaluation;
    if (result != null && result.available) {
      _completedScores.add(result.score);
    }
    _stopVoiceFeatures();
    setState(() {
      _index++;
      _answer.clear();
      _evaluation = null;
      _showSample = false;
      _listening = false;
      _speaking = false;
      _voiceMessage = 'পরের প্রশ্নের জন্য প্রস্তুত।';
    });
  }

  void _restart() {
    _stopVoiceFeatures();
    setState(() {
      _index = 0;
      _completedScores.clear();
      _answer.clear();
      _evaluation = null;
      _showSample = false;
      _listening = false;
      _speaking = false;
    });
    widget.onRestart?.call();
  }

  int get _averageScore {
    if (_completedScores.isEmpty) return 0;
    return (_completedScores.reduce((a, b) => a + b) /
            _completedScores.length)
        .round();
  }

  Widget _sectionTitle(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      );

  Widget _termChips(List<String> terms, Color color) {
    if (terms.isEmpty) return const Text('কোনো শব্দের মিল পাওয়া যায়নি।');
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final term in terms)
          Chip(
            visualDensity: VisualDensity.compact,
            label: Text(term),
            side: BorderSide(color: color.withValues(alpha: 0.35)),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final question = _question;

    if (widget.questions.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('এখন কোনো প্রকাশিত Mock Interview প্রশ্ন পাওয়া যায়নি।'),
              const SizedBox(height: 8),
              const Text(
                'Admin Panel থেকে Interview প্রশ্ন প্রকাশ করার পর এখানে অনুশীলন করা যাবে।',
              ),
              if (widget.onRestart != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: widget.onRestart,
                    icon: const Icon(Icons.refresh),
                    label: const Text('আবার চেষ্টা করুন'),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    if (question == null) {
      final average = _averageScore;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.emoji_events_outlined, size: 38),
              const SizedBox(height: 8),
              Text(
                'অনুশীলন সম্পন্ন',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text('মূল্যায়ন করা প্রশ্ন: ${_completedScores.length}টি'),
              if (_completedScores.isNotEmpty)
                Text(
                  'গড় নমুনা-মিল সূচক: $average%',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              const SizedBox(height: 8),
              const Text(
                'এটি নমুনা উত্তরের সঙ্গে শব্দ ও উত্তরের দৈর্ঘ্যের তুলনা; AI মূল্যায়ন বা পেশাগত যোগ্যতার স্কোর নয়।',
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _restart,
                icon: const Icon(Icons.replay),
                label: const Text('আবার অনুশীলন করুন'),
              ),
            ],
          ),
        ),
      );
    }

    final questionTitle = _text(question, 'title');
    final sampleAnswer = _text(question, 'body');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.record_voice_over_outlined),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.role.isEmpty ? 'Mock Interview' : widget.role,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text('${_index + 1}/${widget.questions.length}'),
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: (_index + 1) / widget.questions.length,
                ),
                const SizedBox(height: 14),
                Text(
                  'প্রশ্ন ${_index + 1}',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
                const SizedBox(height: 6),
                Text(
                  questionTitle,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800, height: 1.35),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _speaking ? _stopSpeaking : _speakQuestion,
                      icon: Icon(_speaking ? Icons.stop : Icons.volume_up),
                      label: Text(_speaking ? 'পড়া বন্ধ' : 'প্রশ্ন শুনুন'),
                    ),
                    ChoiceChip(
                      label: const Text('বাংলা'),
                      selected: _localeTag == 'bn-BD',
                      onSelected: (_) => setState(() => _localeTag = 'bn-BD'),
                    ),
                    ChoiceChip(
                      label: const Text('English'),
                      selected: _localeTag == 'en-US',
                      onSelected: (_) => setState(() => _localeTag = 'en-US'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        _sectionTitle(context, 'আপনার উত্তর'),
        TextField(
          controller: _answer,
          minLines: 4,
          maxLines: 8,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'এখানে লিখুন অথবা মাইক্রোফোনে উত্তর বলুন…',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _listening ? _stopListening : _startListening,
              icon: Icon(_listening ? Icons.stop : Icons.mic),
              label: Text(_listening ? 'ভয়েস বন্ধ করুন' : 'ভয়েসে উত্তর দিন'),
            ),
            OutlinedButton.icon(
              onPressed: _answer.text.trim().isEmpty
                  ? null
                  : () => setState(() => _answer.clear()),
              icon: const Icon(Icons.clear),
              label: const Text('উত্তর মুছুন'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _voiceMessage,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Text(
          'ভয়েস ইনপুটের জন্য Android 12+ এবং ফোনে ইনস্টল করা অফলাইন ভাষা মডেল প্রয়োজন। ভয়েস বা উত্তর সার্ভারে পাঠানো হয় না।',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _answer.text.trim().isEmpty ? null : _evaluateAnswer,
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('উত্তর মূল্যায়ন করুন'),
        ),
        if (_evaluation != null) ...[
          const SizedBox(height: 12),
          Card(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(context, 'অনুশীলনের ফলাফল'),
                  if (_evaluation!.available) ...[
                    Text(
                      '${_evaluation!.score}% নমুনা-মিল সূচক',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text('উত্তরের শব্দ: ${_evaluation!.answerWordCount}'),
                    const SizedBox(height: 8),
                    Text(_evaluation!.feedback),
                    const SizedBox(height: 10),
                    Text(
                      'মিলে পাওয়া বিষয়',
                      style: theme.textTheme.labelLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    _termChips(_evaluation!.matchedTerms, Colors.green),
                    const SizedBox(height: 8),
                    Text(
                      'নমুনা উত্তরে ছিল, আপনার উত্তরে মেলেনি',
                      style: theme.textTheme.labelLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    _termChips(
                      _evaluation!.missingTerms,
                      theme.colorScheme.error,
                    ),
                  ] else
                    Text(_evaluation!.feedback),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () =>
                        setState(() => _showSample = !_showSample),
                    icon: Icon(_showSample
                        ? Icons.visibility_off_outlined
                        : Icons.menu_book_outlined),
                    label: Text(
                      _showSample ? 'নমুনা উত্তর লুকান' : 'নমুনা উত্তর দেখুন',
                    ),
                  ),
                  if (_showSample && sampleAnswer.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SelectableText(sampleAnswer),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _nextQuestion,
            icon: Icon(_index + 1 == widget.questions.length
                ? Icons.flag_outlined
                : Icons.arrow_forward),
            label: Text(_index + 1 == widget.questions.length
                ? 'ফলাফল দেখুন'
                : 'পরবর্তী প্রশ্ন'),
          ),
        ],
        const SizedBox(height: 8),
        if (widget.onRestart != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _restart,
              icon: const Icon(Icons.refresh),
              label: const Text('নতুন অনুশীলন শুরু'),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          'মূল্যায়নটি ফোনেই চলে এবং নমুনা উত্তরের সঙ্গে সাধারণ শব্দ ও দৈর্ঘ্যের মিল দেখে। এটি AI নয়; তথ্যের সত্যতা বা উত্তরের পূর্ণ মান যাচাই করে না।',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

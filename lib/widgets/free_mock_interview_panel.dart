import 'dart:async';

import 'package:flutter/material.dart';
import '../services/mock_interview_evaluator.dart';
import '../services/offline_voice_service.dart';
import '../settings/app_settings.dart';

/// Free, local-only text and voice practice for the existing question bank.
/// Voice features never fall back to an online recognizer or network TTS.
class FreeMockInterviewPanel extends StatefulWidget {
  const FreeMockInterviewPanel({
    super.key,
    required this.questions,
    required this.role,
    this.onRestart,
    this.voiceMode = true,
  });

  final List<Map<String, dynamic>> questions;
  final String role;
  final VoidCallback? onRestart;
  final bool voiceMode;

  @override
  State<FreeMockInterviewPanel> createState() => _FreeMockInterviewPanelState();
}

class _FreeMockInterviewPanelState extends State<FreeMockInterviewPanel>
    with AutomaticKeepAliveClientMixin<FreeMockInterviewPanel> {
  // Retain the answer and progress when mode controls are scrolled offscreen.
  @override
  bool get wantKeepAlive => true;
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
  String _tr(String bn, String en) => AppText.of(context, bn, en);

  Map<String, dynamic>? get _question =>
      _index < widget.questions.length ? widget.questions[_index] : null;

  String _text(Map<String, dynamic>? row, String key) =>
      row?[key]?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    if (widget.voiceMode) _subscribeVoice();
  }

  void _subscribeVoice() {
    if (_voiceSubscription != null) return;
    _voiceSubscription = OfflineVoiceService.events.listen(
      _handleVoiceEvent,
      onError: (_) {
        if (mounted && widget.voiceMode) {
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
    if (oldWidget.voiceMode != widget.voiceMode) {
      if (widget.voiceMode) {
        _subscribeVoice();
        _voiceMessage = 'ভয়েস সুবিধা ব্যবহার করতে মাইক্রোফোন চাপুন।';
      } else {
        _voiceSubscription?.cancel();
        _voiceSubscription = null;
        _stopVoiceFeatures();
        _listening = false;
        _speaking = false;
      }
    }
    if (!identical(oldWidget.questions, widget.questions)) {
      _stopVoiceFeatures();
      _index = 0;
      _completedScores.clear();
      _evaluation = null;
      _showSample = false;
      _listening = false;
      _speaking = false;
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
    if (!mounted || !widget.voiceMode) return;
    final type = event['type']?.toString() ?? '';
    if (type == 'partial' || type == 'result') {
      final transcript = event['text']?.toString() ?? '';
      if (transcript.isNotEmpty) {
        setState(() {
          _answer.value = TextEditingValue(
            text: transcript,
            selection: TextSelection.collapsed(offset: transcript.length),
          );
          _evaluation = null;
          if (type == 'result') {
            _listening = false;
            _voiceMessage = 'ভয়েস থেকে লেখা তৈরি হয়েছে। প্রয়োজন হলে সম্পাদনা করুন।';
          }
        });
      } else if (type == 'result') {
        setState(() {
          _listening = false;
          _voiceMessage = 'কোনো কথা শনাক্ত হয়নি। আবার চেষ্টা করুন।';
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
        return 'এই ভাষা অফলাইনে সমর্থিত নয়।';
      case '13':
        return 'এই ভাষার অফলাইন ভয়েস মডেল ইনস্টল নেই।';
      default:
        return 'অফলাইন ভয়েস কাজ করেনি। লিখে উত্তর দিতে পারেন।';
    }
  }

  Future<void> _startListening() async {
    if (!widget.voiceMode || _speaking) return;
    try {
      final granted =
          await OfflineVoiceService.requestMicrophonePermission();
      if (!mounted || !widget.voiceMode) return;
      if (!granted) {
        setState(() => _voiceMessage =
            'মাইক্রোফোন অনুমতি ছাড়া ভয়েস ব্যবহার করা যাবে না।');
        return;
      }
      final available =
          await OfflineVoiceService.isOfflineSpeechAvailable();
      if (!mounted || !widget.voiceMode) return;
      if (!available) {
        setState(() => _voiceMessage =
            'এই ফোনে Android 12+ অন-ডিভাইস Speech Recognition নেই। Text Interview ব্যবহার করুন।');
        return;
      }
      await OfflineVoiceService.startListening(_localeTag);
      if (!mounted || !widget.voiceMode) {
        await _stopVoiceFeatures();
        return;
      }
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
    if (!widget.voiceMode || _listening) return;
    final question = _text(_question, 'title').trim();
    if (question.isEmpty) return;
    try {
      await OfflineVoiceService.stopSpeaking();
      if (!mounted || !widget.voiceMode) return;
      if (mounted) {
        setState(() {
          _speaking = true;
          _voiceMessage = 'ফোনের অফলাইন ভয়েসে প্রশ্ন পড়া হচ্ছে।';
        });
      }
      await OfflineVoiceService.speak(question, _localeTag);
      if (!mounted || !widget.voiceMode) await _stopVoiceFeatures();
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
    } catch (error) {
      debugPrint('Could not cancel offline recognition: $error');
    }
    try {
      await OfflineVoiceService.stopSpeaking();
    } catch (error) {
      debugPrint('Could not stop offline speech: $error');
    }
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
    if (terms.isEmpty) return Text(_tr('কোনো শব্দের মিল পাওয়া যায়নি।', 'No matching terms.'));
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

  String _voiceMessageForLocale() {
    const english = {
      'ভয়েস সুবিধা ব্যবহার করতে মাইক্রোফোন চাপুন।': 'Tap the microphone to answer.',
      'ভয়েস সুবিধা পাওয়া যায়নি। লিখে উত্তর দিতে পারেন।': 'Voice unavailable. You can type your answer.',
      'ভয়েস থেকে লেখা তৈরি হয়েছে। প্রয়োজন হলে সম্পাদনা করুন।': 'Speech transcribed. Edit the text if needed.',
      'কোনো কথা শনাক্ত হয়নি। আবার চেষ্টা করুন।': 'No speech detected. Try again.',
      'শুনছি… উত্তর বলা শেষ হলে Stop চাপুন।': 'Listening… Tap Stop when finished.',
      'প্রশ্ন পড়ে শোনানো যায়নি।': 'Could not read the question aloud.',
      'কথা বোঝা যায়নি। আবার চেষ্টা করুন অথবা লিখে উত্তর দিন।': 'Speech not understood. Try again or type.',
      'ভয়েস সেবা এখন ব্যস্ত। পরে আবার চেষ্টা করুন।': 'Voice service is busy. Try again later.',
      'মাইক্রোফোন অনুমতি প্রয়োজন।': 'Microphone permission required.',
      'ভয়েস ইনপুট বাতিল হয়েছে।': 'Voice input cancelled.',
      'অফলাইন ভয়েস সেবা সংযোগ করা যায়নি।': 'Could not connect to offline voice service.',
      'এই ভাষা অফলাইনে সমর্থিত নয়।': 'This language is not supported offline.',
      'এই ভাষার অফলাইন ভয়েস মডেল ইনস্টল নেই।': 'Offline model for this language is not installed.',
      'অফলাইন ভয়েস কাজ করেনি। লিখে উত্তর দিতে পারেন।': 'Offline voice failed. You can type.',
      'মাইক্রোফোন অনুমতি ছাড়া ভয়েস ব্যবহার করা যাবে না।': 'Voice requires microphone permission.',
      'এই ফোনে Android 12+ অন-ডিভাইস Speech Recognition নেই। Text Interview ব্যবহার করুন।': 'On-device speech recognition is unavailable. Use text mode.',
      'এই ফোনে অফলাইন ভয়েস মডেল পাওয়া যায়নি।': 'Offline voice model unavailable.',
      'মাইক্রোফোন চালু করা যায়নি। লিখে উত্তর দিতে পারেন।': 'Could not start microphone. You can type.',
      'ভয়েস ইনপুট বন্ধ হয়েছে। লেখা সম্পাদনা করতে পারেন।': 'Voice stopped. You can edit the text.',
      'ফোনের অফলাইন ভয়েসে প্রশ্ন পড়া হচ্ছে।': 'Reading the question using offline voice.',
      'এই ভাষার অফলাইন Text-to-Speech ভয়েস ফোনে ইনস্টল নেই।': 'Offline TTS voice for this language is not installed.',
      'পরের প্রশ্নের জন্য প্রস্তুত।': 'Ready for the next question.',
    };
    return _tr(_voiceMessage, english[_voiceMessage] ?? 'Voice status unavailable.');
  }

  String _feedbackForLocale(MockInterviewEvaluation result) {
    final english = !result.available
      ? (result.answerWordCount == 0 ? 'Provide an answer first.' : 'No usable sample answer is available.')
      : result.score >= 80
        ? 'Good word overlap with the sample. Verify the facts yourself.'
        : result.score >= 55
          ? 'Some important terms match. Review the unmatched terms.'
          : 'Add more relevant points and review the sample answer.';
    return _tr(result.feedback, english);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final question = _question;

    if (widget.questions.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.question_answer_outlined, size: 34,
              color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(_tr('এখনো কোনো প্রশ্ন পাওয়া যায়নি।', 'No questions found yet.'),
              textAlign: TextAlign.center),
          ]),
        ),
      );
    }

    if (question == null) {
      final average = _averageScore;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.emoji_events_outlined, size: 38),
              const SizedBox(height: 8),
              Text(
                _tr('অনুশীলন সম্পন্ন', 'Practice complete'),
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(_tr('মূল্যায়ন করা প্রশ্ন: ${_completedScores.length}টি', 'Evaluated questions: ${_completedScores.length}')),
              if (_completedScores.isNotEmpty)
                Text(
                  _tr('গড় নমুনা-মিল সূচক: $average%', 'Average sample-match indicator: $average%'),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              const SizedBox(height: 8),
              Text(_tr('এটি নমুনা উত্তরের সঙ্গে শব্দ ও উত্তরের দৈর্ঘ্যের তুলনা; AI মূল্যায়ন বা পেশাগত যোগ্যতার স্কোর নয়।', 'This compares words and answer length with the sample; it is not an AI assessment or competence score.')),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _restart,
                icon: const Icon(Icons.replay),
                label: Text(_tr('আবার অনুশীলন করুন', 'Practice again')),
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
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(widget.voiceMode ? Icons.mic_none_rounded : Icons.edit_note_rounded, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.role.isEmpty ? _tr('অনুশীলন', 'Practice') : widget.role,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text('${_index + 1}/${widget.questions.length}', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: _index / widget.questions.length,
                  borderRadius: BorderRadius.circular(6),
                ),
                const SizedBox(height: 14),
                Text(
                  _tr('প্রশ্ন ${_index + 1}', 'Question ${_index + 1}'),
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
                const SizedBox(height: 6),
                Text(
                  questionTitle,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800, height: 1.35),
                ),
                if (widget.voiceMode) const SizedBox(height: 8),
                if (widget.voiceMode) Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _listening ? null : (_speaking ? _stopSpeaking : _speakQuestion),
                      icon: Icon(_speaking ? Icons.stop : Icons.volume_up),
                      label: Text(_speaking ? _tr('পড়া বন্ধ', 'Stop reading') : _tr('প্রশ্ন শুনুন', 'Hear question')),
                    ),
                    ChoiceChip(
                      label: const Text('বাংলা'),
                      selected: _localeTag == 'bn-BD',
                      onSelected: _listening || _speaking ? null : (_) => setState(() => _localeTag = 'bn-BD'),
                    ),
                    ChoiceChip(
                      label: const Text('English'),
                      selected: _localeTag == 'en-US',
                      onSelected: _listening || _speaking ? null : (_) => setState(() => _localeTag = 'en-US'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        _sectionTitle(context, _tr('আপনার উত্তর', 'Your answer')),
        TextField(
          key: const ValueKey('mock-answer'),
          controller: _answer,
          onChanged: (_) => setState(() {
            _evaluation = null;
            _showSample = false;
          }),
          minLines: 3,
          maxLines: 8,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: widget.voiceMode ? _tr('বলুন অথবা লিখুন…', 'Speak or type…') : _tr('এখানে উত্তর লিখুন…', 'Type your answer…'),
            filled: true, fillColor: theme.colorScheme.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (widget.voiceMode) FilledButton.icon(
              onPressed: _speaking ? null : (_listening ? _stopListening : _startListening),
              icon: Icon(_listening ? Icons.stop : Icons.mic),
              label: Text(_listening ? _tr('ভয়েস বন্ধ করুন', 'Stop voice') : _tr('ভয়েসে উত্তর দিন', 'Speak answer')),
            ),
            OutlinedButton.icon(
              onPressed: _answer.text.trim().isEmpty
                  ? null
                  : () => setState(() { _answer.clear(); _evaluation = null; _showSample = false; }),
              icon: const Icon(Icons.clear),
              label: Text(_tr('উত্তর মুছুন', 'Clear answer')),
            ),
          ],
        ),
        if (widget.voiceMode) const SizedBox(height: 6),
        if (widget.voiceMode) Text(
          _voiceMessageForLocale(),
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        if (widget.voiceMode) const SizedBox(height: 4),
        if (widget.voiceMode) Text(
          _tr('অফলাইন ভয়েস • Android 12+ প্রয়োজন', 'Offline voice • Android 12+ required'),
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _answer.text.trim().isEmpty || _listening || _speaking ? null : _evaluateAnswer,
          icon: const Icon(Icons.fact_check_outlined),
          label: Text(_tr('উত্তর মূল্যায়ন করুন', 'Check answer')),
        ),
        if (_evaluation != null) ...[
          const SizedBox(height: 12),
          Card(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(context, _tr('অনুশীলনের ফলাফল', 'Practice feedback')),
                  if (_evaluation!.available) ...[
                    Text(
                      _tr('${_evaluation!.score}% নমুনা-মিল সূচক', '${_evaluation!.score}% sample-match indicator'),
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(_tr('উত্তরের শব্দ: ${_evaluation!.answerWordCount}', 'Answer words: ${_evaluation!.answerWordCount}')),
                    const SizedBox(height: 8),
                    Text(_feedbackForLocale(_evaluation!)),
                    const SizedBox(height: 10),
                    Text(
                      _tr('মিলে পাওয়া বিষয়', 'Matching terms'),
                      style: theme.textTheme.labelLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    _termChips(_evaluation!.matchedTerms, Colors.green),
                    const SizedBox(height: 8),
                    Text(
                      _tr('নমুনা উত্তরে ছিল, আপনার উত্তরে মেলেনি', 'Sample terms not matched'),
                      style: theme.textTheme.labelLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    _termChips(
                      _evaluation!.missingTerms,
                      theme.colorScheme.error,
                    ),
                  ] else
                    Text(_feedbackForLocale(_evaluation!)),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () =>
                        setState(() => _showSample = !_showSample),
                    icon: Icon(_showSample
                        ? Icons.visibility_off_outlined
                        : Icons.menu_book_outlined),
                    label: Text(
                      _showSample ? _tr('নমুনা উত্তর লুকান', 'Hide sample') : _tr('নমুনা উত্তর দেখুন', 'Show sample'),
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
            onPressed: _listening || _speaking ? null : _nextQuestion,
            icon: Icon(_index + 1 == widget.questions.length
                ? Icons.flag_outlined
                : Icons.arrow_forward),
            label: Text(_index + 1 == widget.questions.length
                ? _tr('ফলাফল দেখুন', 'View summary')
                : _tr('পরবর্তী প্রশ্ন', 'Next question')),
          ),
        ],
        const SizedBox(height: 8),
        if (widget.onRestart != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _restart,
              icon: const Icon(Icons.refresh),
              label: Text(_tr('নতুন অনুশীলন শুরু', 'Restart practice')),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          _tr('নমুনা-মিল সূচক • AI মূল্যায়ন নয়।', 'Sample-match indicator • Not an AI assessment.'),
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

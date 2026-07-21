import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/learn_controller.dart';
import '../core/service_locator.dart';
import '../models/keyword_card.dart';
import '../models/quiz.dart';
import '../models/unit.dart';

// ---- 팔레트(learning 디자인: 틸/그린 · 흰 배경) ----
const _teal = Color(0xFF178A6E); // 제목/브랜드
const _deepTeal = Color(0xFF0F5C48); // 키워드 대문자
const _midTeal = Color(0xFF35A088); // 뜻/문장
const _correct = Color(0xFF2FBF4E); // 정답
const _wrong = Color(0xFFEF3E3E); // 오답
const _pill = Color(0xFFCFE6DC); // 선택지 기본
const _pillInk = Color(0xFF163A2E);
const _badge = Color(0xFF97A4A0); // 선택지 번호
const _muted = Color(0xFF9AA6A2); // '학습하기/복습하기' 라벨

/// "학습하기" 화면. 마감된 복습을 먼저(1→2→3단계), 그다음 신규 단원을 학습한다.
class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Services.instance;
    return ChangeNotifierProvider(
      create: (_) => LearnController(
        unitRepo: s.unitRepository,
        reviewRepo: s.reviewRepository,
        engine: s.reviewEngine,
      )..start(),
      child: const _LearnView(),
    );
  }
}

class _LearnView extends StatelessWidget {
  const _LearnView();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LearnController>();
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: c.isEmpty
            ? const _Notes()
            : c.isFinished
                ? const _Done()
                : _Step(controller: c),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.controller});
  final LearnController controller;

  @override
  Widget build(BuildContext context) {
    final step = controller.current!;
    final key = ValueKey('${step.unit.id}_${controller.index}');

    if (step.kind == StepKind.learn) {
      return _CardPager(
        key: key,
        unit: step.unit,
        label: '학습하기',
        review: false,
        onDone: controller.completeLearn,
      );
    }
    // 복습: 단계별.
    final quiz = controller.quizForCurrent();
    if (step.stage >= 3 && quiz != null) {
      return _AppliedReview(
          key: key, unit: step.unit, quiz: quiz, onAnswer: controller.answerReview);
    }
    if (step.stage == 2 && quiz != null) {
      return _OxReview(
          key: key, unit: step.unit, quiz: quiz, onAnswer: controller.answerReview);
    }
    // 1단계(키워드+뜻 재인지). 문항이 없을 때도 이 화면으로.
    return _CardPager(
      key: key,
      unit: step.unit,
      label: '복습하기',
      review: true,
      onDone: () => controller.answerReview(true),
    );
  }
}

// ---- 공통 헤더 ----

/// 뒤로가기 + "{과목} {n}단원-{키워드}" + '학습하기/복습하기' 라벨(+구분선).
class _LessonHeader extends StatelessWidget {
  const _LessonHeader({
    required this.unit,
    required this.label,
    this.keyword = '',
    this.divider = false,
  });

  final Unit unit;
  final String label;
  final String keyword;
  final bool divider;

  String get _title {
    final subj = unit.subjectName.isNotEmpty ? '${unit.subjectName} ' : '';
    final kw = keyword.isNotEmpty ? '-$keyword' : '';
    return '$subj${unit.unitNo}단원$kw';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: _teal),
              onPressed: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: Text(_title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800, color: _teal)),
            ),
            const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: 20),
        Text(label,
            style: const TextStyle(fontSize: 18, color: _muted)),
        if (divider) ...[
          const SizedBox(height: 12),
          Container(
              height: 1, color: const Color(0xFFE0E0E0), margin: const EdgeInsets.symmetric(horizontal: 24)),
        ],
      ],
    );
  }
}

// ---- 학습 / 복습 1단계: 키워드 카드 넘겨보기 ----

/// 단원의 키워드 카드를 한 장씩 넘긴다.
/// [review]=false(학습): 그림 + 뜻. [review]=true(1단계): 키워드 크게 + 뜻.
class _CardPager extends StatefulWidget {
  const _CardPager({
    super.key,
    required this.unit,
    required this.label,
    required this.review,
    required this.onDone,
  });

  final Unit unit;
  final String label;
  final bool review;
  final Future<void> Function() onDone;

  @override
  State<_CardPager> createState() => _CardPagerState();
}

class _CardPagerState extends State<_CardPager> {
  int _i = 0;
  AudioPlayer? _player;

  List<KeywordCard> get _cards => widget.unit.keywordCards;

  Future<void> _playAudio() async {
    final path = widget.unit.audioPath;
    if (path == null || !File(path).existsSync()) return;
    _player ??= AudioPlayer();
    await _player!.stop();
    await _player!.play(DeviceFileSource(path));
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_i + 1 < _cards.length) {
      setState(() => _i++);
    } else {
      await _player?.stop();
      await widget.onDone();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 키워드가 없으면 쉬운글 본문을 한 장으로 보여 준다.
    if (_cards.isEmpty) return _contentFallback();

    final card = _cards[_i];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _LessonHeader(
              unit: widget.unit,
              label: widget.label,
              keyword: card.keyword,
              divider: widget.review),
          Expanded(
            child: widget.review
                ? _reviewBody(card)
                : _learnBody(card),
          ),
          _nextButton(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // 학습: 그림(플레이스홀더) + 뜻 + 소리 듣기.
  Widget _learnBody(KeywordCard card) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 24),
          _Illustration(card: card, onPlay: _playAudio),
          const SizedBox(height: 28),
          Text(card.meaning,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 22, height: 1.5, fontWeight: FontWeight.w600, color: _midTeal)),
        ],
      ),
    );
  }

  // 복습 1단계: 키워드 크게 + 뜻.
  Widget _reviewBody(KeywordCard card) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(card.keyword,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 64, fontWeight: FontWeight.w900, color: _deepTeal)),
            const SizedBox(height: 32),
            Text(card.meaning,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 24, height: 1.5, fontWeight: FontWeight.w700, color: _midTeal)),
          ],
        ),
      ),
    );
  }

  Widget _nextButton() {
    final last = _i + 1 >= _cards.length;
    return SizedBox(
      height: 76,
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(backgroundColor: _teal),
        onPressed: _next,
        child: Text(last ? '다 봤어요' : '다음',
            style: const TextStyle(fontSize: 22)),
      ),
    );
  }

  Widget _contentFallback() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _LessonHeader(
              unit: widget.unit, label: widget.label, divider: widget.review),
          Expanded(
            child: SingleChildScrollView(
              child: Text(widget.unit.content,
                  style: const TextStyle(fontSize: 20, height: 1.6)),
            ),
          ),
          SizedBox(
            height: 76,
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _teal),
              onPressed: () => widget.onDone(),
              child: const Text('다 봤어요', style: TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// 개념 그림 자리(실제 이미지 생성 전에는 플레이스홀더). 소리 듣기 버튼 포함.
class _Illustration extends StatelessWidget {
  const _Illustration({required this.card, required this.onPlay});
  final KeywordCard card;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final path = card.imagePath;
    final hasImage = path != null && File(path).existsSync();
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F1E9),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: hasImage
                ? Image.file(File(path), fit: BoxFit.contain)
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.image_outlined,
                          size: 56, color: _badge),
                      const SizedBox(height: 8),
                      Text(card.keyword,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: _deepTeal)),
                    ],
                  ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              child: IconButton(
                icon: const Icon(Icons.volume_up, color: _teal),
                onPressed: onPlay,
                tooltip: '소리 듣기',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---- 복습 2단계: O/X ----

class _OxReview extends StatefulWidget {
  const _OxReview(
      {super.key, required this.unit, required this.quiz, required this.onAnswer});
  final Unit unit;
  final Quiz quiz;
  final Future<void> Function(bool correct) onAnswer;

  @override
  State<_OxReview> createState() => _OxReviewState();
}

class _OxReviewState extends State<_OxReview> {
  int? _picked;

  String get _keyword =>
      widget.unit.keywordCards.isNotEmpty ? widget.unit.keywordCards.first.keyword : '';

  @override
  Widget build(BuildContext context) {
    final q = widget.quiz;
    final answered = _picked != null;
    final correct = answered && q.isCorrect(_picked!);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _LessonHeader(
              unit: widget.unit, label: '복습하기', keyword: _keyword, divider: true),
          const Spacer(),
          Text(q.question,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 26,
                  height: 1.5,
                  fontWeight: FontWeight.w800,
                  color: (answered && !correct) ? _wrong : _midTeal)),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _oxButton(0, Icons.circle_outlined),
              _oxButton(1, Icons.close),
            ],
          ),
          const SizedBox(height: 20),
          if (answered)
            Text(correct ? '정답입니다!' : '아쉬워요. 내일 다시 볼게요.',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: correct ? _correct : _wrong)),
          const Spacer(),
          if (answered)
            _NextBar(onNext: () => widget.onAnswer(correct)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _oxButton(int value, IconData icon) {
    final answered = _picked != null;
    final isThis = _picked == value;
    Color color = Colors.black87;
    if (answered && isThis) {
      color = widget.quiz.isCorrect(value) ? _correct : _wrong;
    }
    return IconButton(
      iconSize: 72,
      onPressed: answered ? null : () => setState(() => _picked = value),
      icon: Icon(icon, color: color),
    );
  }
}

// ---- 복습 3단계: 유사(응용) 4지선다 ----

class _AppliedReview extends StatefulWidget {
  const _AppliedReview(
      {super.key, required this.unit, required this.quiz, required this.onAnswer});
  final Unit unit;
  final Quiz quiz;
  final Future<void> Function(bool correct) onAnswer;

  @override
  State<_AppliedReview> createState() => _AppliedReviewState();
}

class _AppliedReviewState extends State<_AppliedReview> {
  int? _picked;

  String get _keyword =>
      widget.unit.keywordCards.isNotEmpty ? widget.unit.keywordCards.first.keyword : '';

  @override
  Widget build(BuildContext context) {
    final q = widget.quiz;
    final answered = _picked != null;
    final correct = answered && q.isCorrect(_picked!);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LessonHeader(
              unit: widget.unit, label: '복습하기', keyword: _keyword, divider: true),
          const SizedBox(height: 20),
          Text(q.question,
              style: const TextStyle(
                  fontSize: 20, height: 1.4, fontWeight: FontWeight.w700, color: _teal)),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (var i = 0; i < q.choices.length; i++)
                    _ChoiceRow(
                      number: i + 1,
                      text: q.choices[i],
                      state: !answered
                          ? _ChoiceState.idle
                          : i == q.answer
                              ? _ChoiceState.correct
                              : (i == _picked ? _ChoiceState.wrong : _ChoiceState.idle),
                      onTap: answered ? null : () => setState(() => _picked = i),
                    ),
                ],
              ),
            ),
          ),
          if (answered) _NextBar(onNext: () => widget.onAnswer(correct)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

enum _ChoiceState { idle, correct, wrong }

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow(
      {required this.number,
      required this.text,
      required this.state,
      required this.onTap});
  final int number;
  final String text;
  final _ChoiceState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (badge, pill, ink) = switch (state) {
      _ChoiceState.correct => (_correct, _correct, Colors.white),
      _ChoiceState.wrong => (_wrong, _wrong, Colors.white),
      _ChoiceState.idle => (_badge, _pill, _pillInk),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: badge,
              child: Text('$number',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  color: pill,
                  borderRadius: BorderRadius.circular(24),
                ),
                alignment: Alignment.center,
                child: Text(text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700, color: ink)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextBar extends StatelessWidget {
  const _NextBar({required this.onNext});
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(backgroundColor: _teal),
        onPressed: onNext,
        child: const Text('다음', style: TextStyle(fontSize: 22)),
      ),
    );
  }
}

// ---- 종료 / 노트 ----

class _Done extends StatelessWidget {
  const _Done();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/turtle_trophy.png', width: 160),
          const SizedBox(height: 24),
          const Text('오늘 학습을 마쳤어요!', style: TextStyle(fontSize: 26)),
          const SizedBox(height: 12),
          const Text('잘했어요. 내일 또 만나요.', style: TextStyle(fontSize: 20)),
          const SizedBox(height: 40),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _teal),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인', style: TextStyle(fontSize: 22)),
          ),
        ],
      ),
    );
  }
}

/// 오늘 복습·학습할 게 없을 때의 안내(단원 목록은 노출하지 않는다 —
/// 복습 주기는 AI가 자동으로 관리하므로 사용자가 목록을 뒤질 필요가 없다).
class _Notes extends StatelessWidget {
  const _Notes();

  @override
  Widget build(BuildContext context) {
    final hasUnits = Services.instance.unitRepository.all().isNotEmpty;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.spa, size: 96, color: _midTeal),
          const SizedBox(height: 24),
          Text(hasUnits ? '오늘 복습·학습을 마쳤어요!' : '아직 학습할 내용이 없어요.',
              style: const TextStyle(fontSize: 26)),
          const SizedBox(height: 12),
          Text(hasUnits ? '내일 또 만나요.' : '먼저 강의를 녹음해 보세요.',
              style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 40),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _teal),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인', style: TextStyle(fontSize: 22)),
          ),
        ],
      ),
    );
  }
}

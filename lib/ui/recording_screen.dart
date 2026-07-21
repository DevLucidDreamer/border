import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/recording_controller.dart';
import '../core/service_locator.dart';
import '../models/enums.dart';

/// 입력 처리 화면. 녹음/음성 업로드/PDF 업로드 모두 이 화면을 재사용한다.
/// 한 화면에서 입력 → 자동 정리 → 완료까지, 항상 하나의 과업만 보여준다.
class RecordingScreen extends StatelessWidget {
  const RecordingScreen({super.key, required this.onStart, this.title = '녹음'});

  /// 컨트롤러가 만들어지면 실행할 시작 동작(녹음 시작 / 파일 처리 등).
  final void Function(RecordingController controller) onStart;
  final String title;

  /// 앱에서 직접 녹음하는 화면.
  static RecordingScreen record() =>
      RecordingScreen(title: '녹음', onStart: (c) => c.startRecording());

  /// 업로드된 음성 파일을 처리하는 화면.
  static RecordingScreen audioFile(String path) => RecordingScreen(
      title: '음성 파일', onStart: (c) => c.ingestAudioFile(path));

  /// 업로드된 PDF를 처리하는 화면.
  static RecordingScreen pdfFile(String path) =>
      RecordingScreen(title: 'PDF', onStart: (c) => c.ingestPdfFile(path));

  @override
  Widget build(BuildContext context) {
    final s = Services.instance;
    return ChangeNotifierProvider(
      create: (_) {
        final controller = RecordingController(
          recorder: s.recorder,
          stt: s.sttService,
          orchestrator: s.orchestrator,
          lectureRepo: s.lectureRepository,
          unitRepo: s.unitRepository,
          timetableRepo: s.timetableRepository,
          subjectClassifier: s.subjectClassifier,
          fileStore: s.fileStore,
          pdfExtractor: s.pdfExtractor,
        );
        onStart(controller);
        return controller;
      },
      child: _RecordingView(title: title),
    );
  }
}

class _RecordingView extends StatelessWidget {
  const _RecordingView({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<RecordingController>();
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: _body(context, c)),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, RecordingController c) {
    switch (c.status) {
      case LectureStatus.recording:
        return _Recording(onStop: c.stopAndProcess);
      case LectureStatus.transcribing:
      case LectureStatus.summarizing:
      case LectureStatus.generatingMedia:
      case LectureStatus.buildingContent:
        return _Processing(status: c.status);
      case LectureStatus.ready:
        return const _Done();
      case LectureStatus.tooShort:
        return const _TooShort();
      case LectureStatus.failed:
        return _Failed(message: c.error);
    }
  }
}

class _Recording extends StatelessWidget {
  const _Recording({required this.onStop});
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.mic, size: 96, color: Colors.red),
        const SizedBox(height: 24),
        const Text('강의를 녹음하고 있어요.', style: TextStyle(fontSize: 24)),
        const SizedBox(height: 48),
        SizedBox(
          height: 120,
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: onStop,
            child: const Text('녹음 끝내기', style: TextStyle(fontSize: 26)),
          ),
        ),
      ],
    );
  }
}

class _Processing extends StatelessWidget {
  const _Processing({required this.status});
  final LectureStatus status;

  String get _label => switch (status) {
        LectureStatus.transcribing => '들은 내용을 옮기고 있어요…',
        LectureStatus.summarizing => '쉽게 정리하고 있어요…',
        LectureStatus.buildingContent => '키워드와 문제를 만들고 있어요…',
        LectureStatus.generatingMedia => '소리로 만들고 있어요…',
        _ => '준비하고 있어요…',
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
            width: 72, height: 72, child: CircularProgressIndicator()),
        const SizedBox(height: 32),
        Text(_label, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 12),
        const Text('잠깐만 기다려 주세요.', style: TextStyle(fontSize: 18)),
      ],
    );
  }
}

/// 정리 완료 화면. 정리된 본문은 "공부하기"에서 보므로 여기선 알림만 한다.
class _Done extends StatelessWidget {
  const _Done();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle, size: 96, color: Colors.green),
        const SizedBox(height: 24),
        const Text('정리가 끝났어요!', style: TextStyle(fontSize: 26)),
        const SizedBox(height: 48),
        SizedBox(
          height: 88,
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인', style: TextStyle(fontSize: 24)),
          ),
        ),
      ],
    );
  }
}

/// 녹음이 너무 짧아(무음·환청) 정리할 내용이 없을 때 보여 준다.
class _TooShort extends StatelessWidget {
  const _TooShort();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.hearing_disabled, size: 96, color: Colors.orange),
        const SizedBox(height: 24),
        const Text('녹음한 내용이 너무 짧아요.', style: TextStyle(fontSize: 24)),
        const SizedBox(height: 8),
        const Text('조금 더 길게 말한 뒤 다시 녹음해 주세요.',
            style: TextStyle(fontSize: 18, color: Colors.grey)),
        const SizedBox(height: 40),
        SizedBox(
          height: 88,
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('다시 녹음', style: TextStyle(fontSize: 24)),
          ),
        ),
      ],
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, size: 72, color: Colors.orange),
        const SizedBox(height: 16),
        const Text('문제가 생겼어요. 다시 해볼까요?',
            style: TextStyle(fontSize: 22)),
        if (message != null) ...[
          const SizedBox(height: 8),
          Text(message!,
              style: const TextStyle(fontSize: 14, color: Colors.grey)),
        ],
        const SizedBox(height: 32),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('돌아가기', style: TextStyle(fontSize: 22)),
        ),
      ],
    );
  }
}

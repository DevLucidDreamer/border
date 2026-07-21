import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../core/platform_media.dart';

/// 로컬 오디오 파일(정리 요약 음성)을 재생/정지하는 큰 버튼.
///
/// 긴 글을 읽기 어려운 학습자를 위해 "들어보기"를 크게 제공한다.
class PlayAudioButton extends StatefulWidget {
  const PlayAudioButton({super.key, required this.filePath});
  final String filePath;

  @override
  State<PlayAudioButton> createState() => _PlayAudioButtonState();
}

class _PlayAudioButtonState extends State<PlayAudioButton> {
  final _player = AudioPlayer();
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.stop();
      if (mounted) setState(() => _playing = false);
    } else {
      await _player.play(audioSource(widget.filePath));
      if (mounted) setState(() => _playing = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      width: double.infinity,
      child: FilledButton.tonalIcon(
        onPressed: _toggle,
        icon: Icon(_playing ? Icons.stop : Icons.volume_up, size: 32),
        label: Text(_playing ? '멈추기' : '정리 들어보기',
            style: const TextStyle(fontSize: 22)),
      ),
    );
  }
}

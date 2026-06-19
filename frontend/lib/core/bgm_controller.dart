import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// 앱 전역 배경음악 컨트롤러 (싱글톤).
/// 어느 화면에서든 [Bgm.instance] 로 접근해 볼륨/켜고끄기 가능.
class Bgm {
  Bgm._();
  static final Bgm instance = Bgm._();

  final AudioPlayer _player = AudioPlayer();

  /// 0.0 ~ 1.0 볼륨. UI가 구독해 슬라이더를 갱신.
  final ValueNotifier<double> volume = ValueNotifier(0.5);

  /// 음악 켜짐 여부.
  final ValueNotifier<bool> enabled = ValueNotifier(true);

  bool _started = false;

  /// 앱 시작 시 한 번만 호출. 끊김 없이 루프 재생.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setVolume(volume.value);
    await _player.play(AssetSource('audio/bgm.mp3'));
  }

  Future<void> setVolume(double v) async {
    volume.value = v;
    await _player.setVolume(v);
  }

  Future<void> setEnabled(bool on) async {
    enabled.value = on;
    if (on) {
      await _player.resume();
    } else {
      await _player.pause();
    }
  }
}

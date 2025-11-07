import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

class AlarmService {
  AlarmService._();
  static final AlarmService instance = AlarmService._();

  bool _isPlaying = false;

  Future<void> startAlarm() async {
    if (_isPlaying) return;
    _isPlaying = true;
    // Use the system alarm sound, loop until stopped.
    await FlutterRingtonePlayer().play(
      android: AndroidSounds.alarm,
      ios: IosSounds.alarm,
      looping: true,
      volume: 1.0,
      asAlarm: true,
    );
  }

  Future<void> stopAlarm() async {
    if (!_isPlaying) return;
    await FlutterRingtonePlayer().stop();
    _isPlaying = false;
  }
}

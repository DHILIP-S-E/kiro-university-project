import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

/// Wraps the `record` package for voice note recording.
/// Call [startRecording] to begin, [stopRecording] to end and get the file.
class AudioService {
  static final AudioRecorder _recorder = AudioRecorder();

  /// Request microphone permission. Returns true if granted.
  static Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  /// Start recording to a temp M4A file.
  /// Throws if microphone permission is denied.
  static Future<void> startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw Exception('Microphone permission denied');
    }
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: path,
    );
  }

  /// Stop recording and return the audio [File].
  /// Returns null if nothing was recorded.
  static Future<File?> stopRecording() async {
    final path = await _recorder.stop();
    if (path == null) return null;
    return File(path);
  }

  /// Whether a recording is currently in progress.
  static Future<bool> isRecording() async {
    return await _recorder.isRecording();
  }

  /// Cancel a recording in progress without saving.
  static Future<void> cancelRecording() async {
    await _recorder.cancel();
  }

  /// Release native resources. Call on widget dispose.
  static Future<void> dispose() async {
    await _recorder.dispose();
  }
}
